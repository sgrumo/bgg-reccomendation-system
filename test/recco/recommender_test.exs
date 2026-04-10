defmodule Recco.RecommenderTest do
  use Recco.DataCase, async: true

  alias Recco.Recommender

  describe "game_recommendations/2" do
    test "returns recommendations from mock" do
      assert {:ok, recs} = Recommender.game_recommendations(1)
      assert length(recs) == 2
      assert hd(recs).bgg_id == 1
    end
  end

  describe "user_recommendations/2" do
    test "returns empty list when user has no ratings" do
      user = insert(:user)
      assert {:ok, []} = Recommender.user_recommendations(user.id)
    end

    test "returns recommendations when user has ratings" do
      user = insert(:user)
      game = insert(:board_game, bgg_id: 100)
      insert(:user_rating, user: user, board_game: game, score: 8.0)

      assert {:ok, recs} = Recommender.user_recommendations(user.id)
      assert length(recs) == 2
    end
  end

  describe "enrich_with_games/1" do
    test "attaches game records to recommendations" do
      game = insert(:board_game, bgg_id: 42)
      recs = [%{bgg_id: 42, name: "Test", score: 0.9}]

      enriched = Recommender.enrich_with_games(recs)

      assert hd(enriched).game.id == game.id
    end

    test "sets game to nil when not found in DB" do
      recs = [%{bgg_id: 999_999, name: "Unknown", score: 0.5}]

      enriched = Recommender.enrich_with_games(recs)

      assert is_nil(hd(enriched).game)
    end
  end
end
