defmodule ReccoWeb.CrawlerLive do
  use ReccoWeb, :live_view

  alias Recco.BoardGames
  alias Recco.BoardGames.Crawler

  @tick_interval 2_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_tick()

    {:ok, assign_crawler_state(socket)}
  end

  @impl true
  def handle_event("start", %{"count" => count_str}, socket) do
    count = String.to_integer(count_str)

    case Crawler.start(count: count) do
      {:ok, _pid} ->
        {:noreply, assign_crawler_state(socket)}

      {:error, {:already_started, _}} ->
        {:noreply, put_flash(socket, :error, "Crawler already running")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start: #{inspect(reason)}")}
    end
  end

  def handle_event("stop", _params, socket) do
    Crawler.stop()
    {:noreply, assign_crawler_state(socket)}
  end

  @impl true
  def handle_info(:tick, socket) do
    schedule_tick()
    {:noreply, assign_crawler_state(socket)}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp assign_crawler_state(socket) do
    crawler_status = Crawler.status()
    game_count = BoardGames.board_game_count()
    crawl_state = BoardGames.get_crawl_state("board_games")

    last_fetched_id =
      case crawl_state do
        {:ok, cs} -> cs.last_fetched_id
        _ -> 0
      end

    {running?, current_id, start_id, max_id, status_text} =
      case crawler_status do
        {:ok, status} ->
          {true, status.current_id, status.start_id, status.max_id, status.status}

        {:error, :not_running} ->
          db_status =
            case crawl_state do
              {:ok, %{status: s}} when s in ["completed", "stopped"] -> s
              _ -> "idle"
            end

          {false, last_fetched_id, 0, 0, db_status}
      end

    total = max_id - start_id + 1
    done = current_id - start_id

    progress =
      if running? and total > 0,
        do: Float.round(done / total * 100, 1),
        else: 0.0

    assign(socket,
      running: running?,
      current_id: current_id,
      max_id: max_id,
      total: total,
      done: done,
      status: status_text,
      progress: progress,
      game_count: game_count,
      last_fetched_id: last_fetched_id
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-8">
      <h1 class="text-2xl font-bold mb-6">BGG Crawler</h1>

      <div class="bg-gray-50 rounded-lg p-6 mb-6 space-y-3">
        <div class="flex justify-between">
          <span class="text-gray-600">Status</span>
          <span class={[
            "font-semibold",
            @status == "running" && "text-green-600",
            @status == "completed" && "text-blue-600",
            @status not in ["running", "completed"] && "text-gray-600"
          ]}>
            {@status}
          </span>
        </div>

        <div class="flex justify-between">
          <span class="text-gray-600">Board games stored</span>
          <span class="font-semibold">{@game_count}</span>
        </div>

        <div class="flex justify-between">
          <span class="text-gray-600">Last fetched ID</span>
          <span class="font-semibold">{@last_fetched_id}</span>
        </div>

        <%= if @running do %>
          <div class="flex justify-between">
            <span class="text-gray-600">Progress</span>
            <span class="font-semibold">{@done} / {@total} ({@progress}%)</span>
          </div>

          <div class="w-full bg-gray-200 rounded-full h-3">
            <div
              class="bg-blue-600 h-3 rounded-full transition-all duration-500"
              style={"width: #{@progress}%"}
            >
            </div>
          </div>
        <% end %>
      </div>

      <%= if @running do %>
        <button
          phx-click="stop"
          class="w-full bg-red-600 text-white py-2 px-4 rounded hover:bg-red-700"
        >
          Stop Crawler
        </button>
      <% else %>
        <form phx-submit="start" class="flex gap-3">
          <input
            type="number"
            name="count"
            value="1000"
            min="1"
            class="flex-1 border rounded px-3 py-2"
            placeholder="Number of IDs to fetch"
          />
          <button
            type="submit"
            class="bg-blue-600 text-white py-2 px-6 rounded hover:bg-blue-700"
          >
            Start Crawler
          </button>
        </form>
      <% end %>
    </div>
    """
  end
end
