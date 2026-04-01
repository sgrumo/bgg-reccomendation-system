defmodule Recco.BoardGames.Crawler do
  use GenServer, restart: :temporary

  require Logger

  alias Recco.BoardGames
  alias Recco.BoardGames.BggApi

  @batch_size 20
  @default_delay_ms 5_000
  @rate_limit_delay_ms 30_000
  @queued_retry_delay_ms 10_000
  @crawl_key "board_games"

  @type status :: %{
          running: boolean(),
          current_id: integer(),
          max_id: integer(),
          status: String.t()
        }

  # Public API

  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    DynamicSupervisor.start_child(
      Recco.DynamicSupervisor,
      {__MODULE__, opts}
    )
  end

  @spec stop() :: :ok | {:error, :not_running}
  def stop do
    case lookup() do
      {:ok, pid} -> safe_call(pid, :stop, {:error, :not_running})
      :error -> {:error, :not_running}
    end
  end

  @spec status() :: {:ok, status()} | {:error, :not_running}
  def status do
    case lookup() do
      {:ok, pid} ->
        case safe_call(pid, :status, {:error, :not_running}) do
          {:error, :not_running} -> {:error, :not_running}
          result -> {:ok, result}
        end

      :error ->
        {:error, :not_running}
    end
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, via_registry())
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    delay_ms = Keyword.get(opts, :delay_ms, @default_delay_ms)

    current_id =
      case BoardGames.get_crawl_state(@crawl_key) do
        {:ok, state} -> state.last_fetched_id + 1
        {:error, :not_found} -> 1
      end

    max_id =
      case Keyword.fetch(opts, :count) do
        {:ok, count} -> current_id + count - 1
        :error -> Keyword.get(opts, :max_id, current_id + 400_000 - 1)
      end

    state = %{
      start_id: current_id,
      current_id: current_id,
      max_id: max_id,
      delay_ms: delay_ms,
      status: "running"
    }

    Logger.info("Crawler starting from ID #{current_id} to #{max_id}")
    send(self(), :fetch_batch)

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    reply = %{
      running: true,
      start_id: state.start_id,
      current_id: state.current_id,
      max_id: state.max_id,
      status: state.status
    }

    {:reply, reply, state}
  end

  def handle_call(:stop, _from, state) do
    Logger.info("Crawler stopping at ID #{state.current_id}")

    BoardGames.upsert_crawl_state(@crawl_key, %{
      last_fetched_id: state.current_id - 1,
      status: "stopped"
    })

    {:stop, :normal, :ok, %{state | status: "stopped"}}
  end

  @impl true
  def handle_info(:fetch_batch, %{current_id: current_id, max_id: max_id} = state)
      when current_id > max_id do
    Logger.info("Crawler completed — reached max ID #{max_id}")
    BoardGames.upsert_crawl_state(@crawl_key, %{status: "completed", last_fetched_id: max_id})
    {:stop, :normal, %{state | status: "completed"}}
  end

  def handle_info(:fetch_batch, state) do
    batch_end = min(state.current_id + @batch_size - 1, state.max_id)
    ids = Enum.to_list(state.current_id..batch_end)

    case BggApi.fetch_board_games(ids) do
      {:ok, games} ->
        Enum.each(games, &BoardGames.upsert_board_game/1)

        BoardGames.upsert_crawl_state(@crawl_key, %{
          last_fetched_id: batch_end,
          status: "running"
        })

        Logger.debug("Crawled IDs #{state.current_id}..#{batch_end}, got #{length(games)} games")
        schedule_next(state.delay_ms)
        {:noreply, %{state | current_id: batch_end + 1}}

      {:error, :rate_limited} ->
        Logger.warning("Rate limited, retrying in #{@rate_limit_delay_ms}ms")
        schedule_next(@rate_limit_delay_ms)
        {:noreply, state}

      {:error, :queued} ->
        Logger.info("Request queued by BGG, retrying in #{@queued_retry_delay_ms}ms")
        schedule_next(@queued_retry_delay_ms)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Crawler error at ID #{state.current_id}: #{inspect(reason)}")
        schedule_next(state.delay_ms)
        {:noreply, %{state | current_id: batch_end + 1}}
    end
  end

  defp schedule_next(delay_ms) do
    Process.send_after(self(), :fetch_batch, delay_ms)
  end

  defp safe_call(pid, message, default) do
    GenServer.call(pid, message)
  catch
    :exit, {:noproc, _} -> default
    :exit, {:normal, _} -> default
    :exit, {:shutdown, _} -> default
  end

  defp via_registry do
    {:via, Registry, {Recco.Registry, __MODULE__}}
  end

  defp lookup do
    case Registry.lookup(Recco.Registry, __MODULE__) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end
end
