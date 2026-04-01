defmodule Recco.BoardGames.CrawlerTest do
  use Recco.DataCase, async: false

  alias Recco.BoardGames
  alias Recco.BoardGames.Crawler

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Recco.Repo, {:shared, self()})
    :ok
  end

  defp start_crawler(opts) do
    name = :"crawler_#{System.unique_integer([:positive])}"
    start_supervised!({Crawler, Keyword.put(opts, :name, name)})
  end

  defp start_and_await(opts) do
    pid = start_crawler(opts)
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000
    pid
  end

  describe "crawl lifecycle" do
    test "fetches board games and marks completed" do
      start_and_await(count: 20, delay_ms: 10)

      assert {:ok, state} = BoardGames.get_crawl_state("board_games")
      assert state.last_fetched_id == 20
      assert state.status == "completed"
    end

    test "stores parsed board games in the database" do
      start_and_await(count: 20, delay_ms: 10)

      assert {:ok, game} = BoardGames.get_board_game_by_bgg_id(174_430)
      assert game.name == "Gloomhaven"

      assert {:ok, catan} = BoardGames.get_board_game_by_bgg_id(13)
      assert catan.name == "CATAN"
    end

    test "resumes from last fetched ID" do
      BoardGames.upsert_crawl_state("board_games", %{last_fetched_id: 10, status: "running"})

      start_and_await(count: 10, delay_ms: 10)

      assert {:ok, state} = BoardGames.get_crawl_state("board_games")
      assert state.last_fetched_id == 20
    end
  end

  describe "stop and status" do
    test "stops a running crawler and persists state" do
      pid = start_crawler(count: 1_000_000, delay_ms: 60_000)
      assert Process.alive?(pid)

      GenServer.call(pid, :stop)

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000

      assert {:ok, state} = BoardGames.get_crawl_state("board_games")
      assert state.status == "stopped"
    end

    test "reports status of running crawler" do
      pid = start_crawler(count: 100, delay_ms: 60_000)

      status = GenServer.call(pid, :status)
      assert status.running == true
    end
  end

  describe "public API" do
    test "start/stop/status via module functions" do
      assert {:error, :not_running} = Crawler.status()
      assert {:error, :not_running} = Crawler.stop()

      assert {:ok, pid} = Crawler.start(count: 1_000_000, delay_ms: 60_000)
      assert {:ok, %{running: true}} = Crawler.status()
      assert {:error, {:already_started, ^pid}} = Crawler.start(count: 100)
      assert :ok = Crawler.stop()
      assert {:error, :not_running} = Crawler.status()
    end
  end
end
