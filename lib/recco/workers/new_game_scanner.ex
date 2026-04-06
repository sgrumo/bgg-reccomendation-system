defmodule Recco.Workers.NewGameScanner do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Recco.BoardGames
  alias Recco.BoardGames.BggApi

  @batch_size 20
  @max_empty_streaks 5
  @delay_ms 5_000

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
  def perform(_job) do
    start_id = BoardGames.max_bgg_id() + 1
    Logger.info("NewGameScanner starting from ID #{start_id}")

    case scan(start_id, 0, 0) do
      {:ok, found} ->
        Logger.info("NewGameScanner finished — found #{found} new games")
        :ok

      {:error, reason} ->
        Logger.error("NewGameScanner failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp scan(_current_id, empty_streaks, found) when empty_streaks >= @max_empty_streaks do
    {:ok, found}
  end

  defp scan(current_id, empty_streaks, found) do
    batch_end = current_id + @batch_size - 1
    ids = Enum.to_list(current_id..batch_end)

    case BggApi.fetch_board_games(ids) do
      {:ok, []} ->
        Process.sleep(@delay_ms)
        scan(batch_end + 1, empty_streaks + 1, found)

      {:ok, games} ->
        Enum.each(games, &BoardGames.upsert_board_game/1)
        Logger.info("NewGameScanner found #{length(games)} games in IDs #{current_id}..#{batch_end}")
        Process.sleep(@delay_ms)
        scan(batch_end + 1, 0, found + length(games))

      {:error, :rate_limited} ->
        Logger.warning("NewGameScanner rate limited, waiting 30s")
        Process.sleep(30_000)
        scan(current_id, empty_streaks, found)

      {:error, :queued} ->
        Logger.info("NewGameScanner request queued, waiting 10s")
        Process.sleep(10_000)
        scan(current_id, empty_streaks, found)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
