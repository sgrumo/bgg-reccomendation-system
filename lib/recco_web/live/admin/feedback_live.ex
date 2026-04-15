defmodule ReccoWeb.Admin.FeedbackLive do
  use ReccoWeb, :live_view

  alias Recco.Feedback

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    stats = Feedback.stats()
    by_source = Feedback.counts_by_source()
    top_liked = Feedback.top_games(true)
    top_disliked = Feedback.top_games(false)
    recent = Feedback.recent_feedback()

    {:ok,
     assign(socket,
       page_title: "Recommendation Feedback",
       stats: stats,
       by_source: by_source,
       top_liked: top_liked,
       top_disliked: top_disliked,
       recent: recent
     )}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold text-zinc-900 mb-8">Recommendation Feedback</h1>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-10">
        <.stat_card title="Total Feedback" value={@stats.total} />
        <.stat_card title="Positive" value={@stats.positive} accent="text-green-600" />
        <.stat_card title="Negative" value={@stats.negative} accent="text-red-600" />
        <.stat_card title="Positive Rate" value={"#{@stats.positive_rate}%"} />
      </div>

      <div :if={@by_source != %{}} class="mb-10">
        <h2 class="text-lg font-bold text-zinc-900 mb-4">By Source</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <div
            :for={{source, counts} <- @by_source}
            class="rounded-lg border border-zinc-200 bg-white p-6"
          >
            <p class="text-sm font-medium text-zinc-500 mb-3">{format_source(source)}</p>
            <div class="flex items-center gap-6">
              <div>
                <p class="text-2xl font-bold text-green-600">{counts.positive}</p>
                <p class="text-xs text-zinc-500">positive</p>
              </div>
              <div>
                <p class="text-2xl font-bold text-red-600">{counts.negative}</p>
                <p class="text-xs text-zinc-500">negative</p>
              </div>
              <div>
                <p class="text-2xl font-bold text-zinc-900">{counts.positive + counts.negative}</p>
                <p class="text-xs text-zinc-500">total</p>
              </div>
            </div>
            <div class="mt-3 h-2 rounded-full bg-zinc-100 overflow-hidden">
              <div
                class="h-full bg-green-500 rounded-full"
                style={"width: #{source_positive_rate(counts)}%"}
              >
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-10 mb-10">
        <div>
          <h2 class="text-lg font-bold text-zinc-900 mb-4">Most Liked Recommendations</h2>
          <.game_list games={@top_liked} empty_text="No positive feedback yet." />
        </div>
        <div>
          <h2 class="text-lg font-bold text-zinc-900 mb-4">Most Disliked Recommendations</h2>
          <.game_list games={@top_disliked} empty_text="No negative feedback yet." />
        </div>
      </div>

      <div>
        <h2 class="text-lg font-bold text-zinc-900 mb-4">Recent Feedback</h2>
        <.recent_table recent={@recent} />
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :accent, :string, default: "text-zinc-900"

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 bg-white p-6">
      <p class="text-sm font-medium text-zinc-500">{@title}</p>
      <p class={["mt-2 text-3xl font-bold", @accent]}>{@value}</p>
    </div>
    """
  end

  attr :games, :list, required: true
  attr :empty_text, :string, required: true

  defp game_list(assigns) do
    ~H"""
    <div :if={@games == []} class="text-sm text-zinc-500">{@empty_text}</div>
    <div class="space-y-2">
      <div
        :for={{game, idx} <- Enum.with_index(@games, 1)}
        class="flex items-center gap-3 rounded-lg border border-zinc-200 bg-white px-4 py-3"
      >
        <span class="text-sm font-bold text-zinc-400 w-6">{idx}</span>
        <div class="w-8 h-8 flex-shrink-0 rounded bg-zinc-100 overflow-hidden">
          <img
            :if={game.thumbnail_url}
            src={game.thumbnail_url}
            alt={game.name}
            class="w-full h-full object-cover"
          />
        </div>
        <a
          href={~p"/games/#{game.board_game_id}"}
          class="flex-1 text-sm font-medium text-zinc-900 hover:underline truncate"
        >
          {game.name}
        </a>
        <span class="text-sm font-bold text-zinc-700">{game.count}</span>
      </div>
    </div>
    """
  end

  attr :recent, :list, required: true

  defp recent_table(assigns) do
    ~H"""
    <div :if={@recent == []} class="text-sm text-zinc-500">No feedback yet.</div>
    <div :if={@recent != []} class="rounded-lg border border-zinc-200 bg-white overflow-hidden">
      <table class="w-full">
        <thead>
          <tr class="border-b border-zinc-100 bg-zinc-50">
            <th class="px-4 py-3 text-left text-xs font-medium text-zinc-500">User</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-zinc-500">Game</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-zinc-500">Feedback</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-zinc-500">Source</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-zinc-500">Date</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={fb <- @recent} class="border-b border-zinc-100 last:border-0">
            <td class="px-4 py-3 text-sm font-medium text-zinc-900">{fb.user.username}</td>
            <td class="px-4 py-3 text-sm text-zinc-700">
              <a href={~p"/games/#{fb.board_game_id}"} class="hover:underline">
                {fb.board_game.name}
              </a>
            </td>
            <td class="px-4 py-3">
              <span class={[
                "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
                fb.positive && "bg-green-100 text-green-700",
                !fb.positive && "bg-red-100 text-red-700"
              ]}>
                {if fb.positive, do: "Positive", else: "Negative"}
              </span>
            </td>
            <td class="px-4 py-3 text-sm text-zinc-500">{format_source(fb.source)}</td>
            <td class="px-4 py-3 text-sm text-zinc-500">
              {Calendar.strftime(fb.inserted_at, "%b %d, %Y")}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp format_source("user_recommendations"), do: "For You"
  defp format_source("similar_games"), do: "Similar Games"
  defp format_source(source), do: source

  defp source_positive_rate(%{positive: p, negative: n}) when p + n > 0 do
    Float.round(p / (p + n) * 100, 1)
  end

  defp source_positive_rate(_), do: 0
end
