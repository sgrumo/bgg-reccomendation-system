defmodule ReccoWeb.Admin.DashboardLive do
  use ReccoWeb, :live_view

  import Ecto.Query

  alias Recco.Accounts
  alias Recco.BoardGames
  alias Recco.BoardGames.Cache
  alias Recco.Observability.Counters
  alias Recco.Ratings
  alias Recco.Repo

  @poll_ms 5_000

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@poll_ms, :refresh)

    {:ok, assign_observability(socket)}
  end

  @impl true
  @spec handle_info(:refresh, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info(:refresh, socket), do: {:noreply, assign_observability(socket)}

  defp assign_observability(socket) do
    counters = Counters.snapshot()

    assign(socket,
      page_title: "Admin Dashboard",
      user_count: Accounts.count_users(),
      game_count: BoardGames.board_game_count(),
      total_ratings: Ratings.total_ratings_count(),
      crawler_status: crawler_status(),
      oban_health: oban_health(),
      auth_failed: Map.get(counters, :auth_failed, 0),
      auth_locked_out: Map.get(counters, :auth_locked_out, 0),
      bgg_429: Map.get(counters, :bgg_429, 0),
      cache_stats: Cache.stats()
    )
  end

  defp crawler_status do
    case BoardGames.get_crawl_state("board_games") do
      {:ok, %{last_fetched_id: last, status: status, updated_at: updated_at}} ->
        %{last_fetched_id: last, status: status, updated_at: updated_at}

      {:error, :not_found} ->
        %{last_fetched_id: 0, status: "never run", updated_at: nil}
    end
  end

  defp oban_health do
    row =
      Repo.one(
        from(j in "oban_jobs",
          select: %{
            executing: filter(count(j.id), j.state == "executing"),
            retryable: filter(count(j.id), j.state == "retryable"),
            discarded: filter(count(j.id), j.state == "discarded")
          }
        )
      )

    row ||
      %{executing: 0, retryable: 0, discarded: 0}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold text-zinc-900 mb-8">Dashboard</h1>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <.stat_card title="Users" value={@user_count} href={~p"/admin/users"} />
        <.stat_card title="Board Games" value={@game_count} />
        <.stat_card title="Total Ratings" value={@total_ratings} />
      </div>

      <h2 class="text-lg font-bold text-zinc-900 mb-4">Observability</h2>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <.info_card title="Crawler">
          <p class="text-sm text-zinc-700">
            Status: <span class="font-semibold">{@crawler_status.status}</span>
          </p>
          <p class="text-sm text-zinc-700">Last fetched ID: {@crawler_status.last_fetched_id}</p>
          <p :if={@crawler_status.updated_at} class="text-xs text-zinc-500 mt-1">
            Updated {format_ago(@crawler_status.updated_at)}
          </p>
        </.info_card>

        <.info_card title="Oban">
          <p class="text-sm text-zinc-700">Executing: {@oban_health.executing}</p>
          <p class="text-sm text-zinc-700">Retryable: {@oban_health.retryable}</p>
          <p class={[
            "text-sm",
            if(@oban_health.discarded > 0, do: "text-red-700 font-semibold", else: "text-zinc-700")
          ]}>
            Discarded: {@oban_health.discarded}
          </p>
          <a href={~p"/admin/jobs"} class="mt-2 inline-block text-xs text-brand-600 hover:underline">
            View jobs &rarr;
          </a>
        </.info_card>

        <.info_card title="Auth (current window)">
          <p class="text-sm text-zinc-700">Failed logins: {@auth_failed}</p>
          <p class="text-sm text-zinc-700">Locked-out hits: {@auth_locked_out}</p>
          <p class="text-sm text-zinc-700">BGG 429s: {@bgg_429}</p>
        </.info_card>

        <.info_card :if={@cache_stats != %{}} title="Cache">
          <p :for={{cache, stats} <- @cache_stats} class="text-sm text-zinc-700">
            <span class="font-semibold">{cache}</span>: {cache_hit_rate(stats)} hit rate ({Map.get(
              stats,
              :hits,
              0
            )} / {Map.get(stats, :hits, 0) + Map.get(stats, :misses, 0)})
          </p>
        </.info_card>
      </div>
    </div>
    """
  end

  defp cache_hit_rate(stats) do
    hits = Map.get(stats, :hits, 0)
    misses = Map.get(stats, :misses, 0)
    total = hits + misses

    if total == 0, do: "—", else: "#{trunc(hits / total * 100)}%"
  end

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :href, :string, default: nil

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 bg-white p-6">
      <p class="text-sm font-medium text-zinc-500">{@title}</p>
      <p class="mt-2 text-3xl font-bold text-zinc-900">{@value}</p>
      <a :if={@href} href={@href} class="mt-3 inline-block text-sm text-brand-600 hover:underline">
        View all &rarr;
      </a>
    </div>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp info_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 bg-white p-6">
      <p class="text-sm font-medium text-zinc-500 mb-3">{@title}</p>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp format_ago(%DateTime{} = dt) do
    seconds = DateTime.diff(DateTime.utc_now(), dt)

    cond do
      seconds < 60 -> "#{seconds}s ago"
      seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds < 86_400 -> "#{div(seconds, 3600)}h ago"
      true -> "#{div(seconds, 86_400)}d ago"
    end
  end

  defp format_ago(_), do: ""
end
