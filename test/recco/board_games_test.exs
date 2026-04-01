defmodule Recco.BoardGamesTest do
  use Recco.DataCase, async: true

  alias Recco.BoardGames

  describe "upsert_board_game/1" do
    test "inserts a new board game" do
      attrs = params_for(:board_game, bgg_id: 1, name: "Gloomhaven")

      assert {:ok, game} = BoardGames.upsert_board_game(attrs)
      assert game.bgg_id == 1
      assert game.name == "Gloomhaven"
    end

    test "updates existing board game on bgg_id conflict" do
      attrs = params_for(:board_game, bgg_id: 1, name: "Original")
      assert {:ok, _} = BoardGames.upsert_board_game(attrs)

      updated_attrs = params_for(:board_game, bgg_id: 1, name: "Updated")
      assert {:ok, game} = BoardGames.upsert_board_game(updated_attrs)
      assert game.name == "Updated"
    end

    test "upsert is idempotent" do
      attrs = params_for(:board_game, bgg_id: 42, name: "Same Game")

      assert {:ok, game1} = BoardGames.upsert_board_game(attrs)
      assert {:ok, game2} = BoardGames.upsert_board_game(attrs)
      assert game1.id == game2.id
    end

    test "returns error for missing bgg_id" do
      assert {:error, :unprocessable_entity, errors} =
               BoardGames.upsert_board_game(%{name: "No ID"})

      assert errors[:bgg_id]
    end
  end

  describe "get_board_game_by_bgg_id/1" do
    test "returns board game by bgg_id" do
      game = insert(:board_game, bgg_id: 99)

      assert {:ok, found} = BoardGames.get_board_game_by_bgg_id(99)
      assert found.id == game.id
    end

    test "returns not_found for missing bgg_id" do
      assert {:error, :not_found} = BoardGames.get_board_game_by_bgg_id(999_999)
    end
  end

  describe "crawl_state" do
    test "upsert_crawl_state/2 creates new state" do
      assert {:ok, state} =
               BoardGames.upsert_crawl_state("test_crawl", %{
                 last_fetched_id: 100,
                 status: "running"
               })

      assert state.key == "test_crawl"
      assert state.last_fetched_id == 100
    end

    test "upsert_crawl_state/2 updates existing state" do
      assert {:ok, _} =
               BoardGames.upsert_crawl_state("test_crawl", %{
                 last_fetched_id: 50,
                 status: "running"
               })

      assert {:ok, state} =
               BoardGames.upsert_crawl_state("test_crawl", %{
                 last_fetched_id: 100,
                 status: "paused"
               })

      assert state.last_fetched_id == 100
      assert state.status == "paused"
    end

    test "get_crawl_state/1 returns existing state" do
      insert(:crawl_state, key: "my_key", last_fetched_id: 50)

      assert {:ok, state} = BoardGames.get_crawl_state("my_key")
      assert state.last_fetched_id == 50
    end

    test "get_crawl_state/1 returns not_found" do
      assert {:error, :not_found} = BoardGames.get_crawl_state("nonexistent")
    end
  end
end
