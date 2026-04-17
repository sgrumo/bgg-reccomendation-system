defmodule ReccoWeb.Admin.CrawlerLive do
  use ReccoWeb, :live_view

  alias Recco.BoardGames
  alias Recco.BoardGames.Crawler

  @tick_interval 2_000

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_tick()

    socket =
      socket
      |> assign_crawler_state()
      |> assign(fetch_bgg_id: "", fetch_result: nil)

    {:ok, socket}
  end

  @impl true
  @spec handle_info(atom(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info(:tick, socket) do
    schedule_tick()
    {:noreply, assign_crawler_state(socket)}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("start", _params, socket) do
    Crawler.start()
    {:noreply, assign_crawler_state(socket)}
  end

  def handle_event("fetch_game", %{"bgg_id" => bgg_id_str}, socket) do
    case Integer.parse(String.trim(bgg_id_str)) do
      {bgg_id, _} when bgg_id > 0 ->
        result =
          case BoardGames.fetch_game_by_bgg_id(bgg_id) do
            {:ok, game} -> {:ok, game.name}
            {:error, :not_found} -> {:error, "No board game found with BGG ID #{bgg_id}"}
            {:error, :rate_limited} -> {:error, "BGG API rate limited, try again later"}
            {:error, :queued} -> {:error, "BGG API is processing, try again in a few seconds"}
            {:error, _reason} -> {:error, "Failed to fetch game from BGG"}
          end

        {:noreply, assign(socket, fetch_result: result, fetch_bgg_id: "")}

      _ ->
        {:noreply, assign(socket, fetch_result: {:error, "Please enter a valid BGG ID"})}
    end
  end

  def handle_event("stop", _params, socket) do
    case Crawler.stop() do
      :ok ->
        :ok

      {:error, :not_running} ->
        case BoardGames.get_crawl_state("board_games") do
          {:ok, state} ->
            BoardGames.upsert_crawl_state("board_games", %{
              status: "stopped",
              last_fetched_id: state.last_fetched_id
            })

          _ ->
            :ok
        end
    end

    {:noreply, assign_crawler_state(socket)}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold text-zinc-900 mb-6">BGG Crawler</h1>

      <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
        <div class="rounded-lg border border-zinc-200 p-4">
          <p class="text-xs text-zinc-500">Status</p>
          <p class={["text-lg font-bold", status_color(@status)]}>{@status}</p>
        </div>
        <div class="rounded-lg border border-zinc-200 p-4">
          <p class="text-xs text-zinc-500">Games Crawled</p>
          <p class="text-lg font-bold text-zinc-900">{@game_count}</p>
        </div>
        <div class="rounded-lg border border-zinc-200 p-4">
          <p class="text-xs text-zinc-500">Last Fetched ID</p>
          <p class="text-lg font-bold text-zinc-900">{@last_fetched_id}</p>
        </div>
        <div class="rounded-lg border border-zinc-200 p-4">
          <p class="text-xs text-zinc-500">Max BGG ID</p>
          <p class="text-lg font-bold text-zinc-900">{@max_bgg_id}</p>
        </div>
      </div>

      <div class="flex gap-3">
        <button
          :if={@status != "running"}
          phx-click="start"
          class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-500"
        >
          Start Crawler
        </button>
        <button
          :if={@status == "running"}
          phx-click="stop"
          class="rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:bg-red-500"
        >
          Stop Crawler
        </button>
      </div>

      <p class="text-xs text-zinc-400 mt-4">Auto-refreshes every 2 seconds.</p>

      <hr class="my-8 border-zinc-200" />

      <h2 class="text-xl font-bold text-zinc-900 mb-4">Fetch Game by BGG ID</h2>
      <p class="text-sm text-zinc-500 mb-4">
        Enter a BoardGameGeek ID to fetch and add a specific game to the database.
      </p>

      <form phx-submit="fetch_game" class="flex items-end gap-3">
        <div>
          <label for="bgg_id" class="block text-sm font-medium text-zinc-700 mb-1">BGG ID</label>
          <input
            type="number"
            name="bgg_id"
            id="bgg_id"
            value={@fetch_bgg_id}
            min="1"
            placeholder="e.g. 174430"
            class="rounded-lg border border-zinc-300 px-3 py-2 text-sm w-40 focus:border-brand-500 focus:ring-brand-500"
            required
          />
        </div>
        <button
          type="submit"
          class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-500"
        >
          Fetch Game
        </button>
      </form>

      <div :if={@fetch_result} class="mt-4">
        <div
          :if={match?({:ok, _}, @fetch_result)}
          class="rounded-lg border border-green-300 bg-green-50 p-3 text-sm text-green-800"
        >
          Game "<strong>{elem(@fetch_result, 1)}</strong>" fetched and saved successfully.
        </div>
        <div
          :if={match?({:error, _}, @fetch_result)}
          class="rounded-lg border border-red-300 bg-red-50 p-3 text-sm text-red-800"
        >
          {elem(@fetch_result, 1)}
        </div>
      </div>
    </div>
    """
  end

  defp assign_crawler_state(socket) do
    {status, last_fetched_id} =
      case BoardGames.get_crawl_state("board_games") do
        {:ok, state} -> {state.status, state.last_fetched_id}
        _ -> {"idle", 0}
      end

    assign(socket,
      page_title: "Crawler",
      status: status,
      last_fetched_id: last_fetched_id,
      game_count: BoardGames.board_game_count(),
      max_bgg_id: BoardGames.max_bgg_id()
    )
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_interval)

  defp status_color("running"), do: "text-green-600"
  defp status_color("paused"), do: "text-yellow-600"
  defp status_color(_), do: "text-zinc-600"
end
