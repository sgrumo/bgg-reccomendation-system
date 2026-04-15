defmodule Recco.FeedbackTest do
  use Recco.DataCase, async: true

  alias Recco.Feedback

  describe "upsert_feedback/3" do
    test "creates new feedback" do
      user = insert(:user)
      game = insert(:board_game)

      assert {:ok, feedback} =
               Feedback.upsert_feedback(user.id, game.id, %{
                 positive: true,
                 source: "user_recommendations"
               })

      assert feedback.positive == true
      assert feedback.source == "user_recommendations"
      assert feedback.user_id == user.id
      assert feedback.board_game_id == game.id
    end

    test "updates existing feedback" do
      user = insert(:user)
      game = insert(:board_game)

      assert {:ok, _} =
               Feedback.upsert_feedback(user.id, game.id, %{
                 positive: true,
                 source: "similar_games"
               })

      assert {:ok, feedback} =
               Feedback.upsert_feedback(user.id, game.id, %{
                 positive: false,
                 source: "similar_games"
               })

      assert feedback.positive == false
    end

    test "validates source inclusion" do
      user = insert(:user)
      game = insert(:board_game)

      assert {:error, :unprocessable_entity, _} =
               Feedback.upsert_feedback(user.id, game.id, %{
                 positive: true,
                 source: "invalid"
               })
    end
  end

  describe "delete_feedback/2" do
    test "deletes existing feedback" do
      feedback = insert(:recommendation_feedback)
      assert :ok = Feedback.delete_feedback(feedback.user_id, feedback.board_game_id)
      assert is_nil(Feedback.get_feedback(feedback.user_id, feedback.board_game_id))
    end

    test "returns not_found for missing feedback" do
      assert {:error, :not_found} =
               Feedback.delete_feedback(Ecto.UUID.generate(), Ecto.UUID.generate())
    end
  end

  describe "get_feedback/2" do
    test "returns feedback when it exists" do
      feedback = insert(:recommendation_feedback)
      result = Feedback.get_feedback(feedback.user_id, feedback.board_game_id)
      assert result.id == feedback.id
    end

    test "returns nil when no feedback exists" do
      assert is_nil(Feedback.get_feedback(Ecto.UUID.generate(), Ecto.UUID.generate()))
    end
  end

  describe "user_feedback_map/1" do
    test "returns board_game_id => positive map" do
      user = insert(:user)
      game1 = insert(:board_game)
      game2 = insert(:board_game)
      insert(:recommendation_feedback, user: user, board_game: game1, positive: true)
      insert(:recommendation_feedback, user: user, board_game: game2, positive: false)

      result = Feedback.user_feedback_map(user.id)

      assert result == %{game1.id => true, game2.id => false}
    end

    test "returns empty map for user with no feedback" do
      user = insert(:user)
      assert Feedback.user_feedback_map(user.id) == %{}
    end
  end

  describe "stats/0" do
    test "returns aggregate stats" do
      user = insert(:user)
      game1 = insert(:board_game)
      game2 = insert(:board_game)
      game3 = insert(:board_game)
      insert(:recommendation_feedback, user: user, board_game: game1, positive: true)
      insert(:recommendation_feedback, user: user, board_game: game2, positive: true)
      insert(:recommendation_feedback, user: user, board_game: game3, positive: false)

      stats = Feedback.stats()

      assert stats.total == 3
      assert stats.positive == 2
      assert stats.negative == 1
      assert_in_delta stats.positive_rate, 66.7, 0.1
    end

    test "returns zeros when no feedback" do
      stats = Feedback.stats()
      assert stats == %{total: 0, positive: 0, negative: 0, positive_rate: 0.0}
    end
  end

  describe "counts_by_source/0" do
    test "groups counts by source" do
      user = insert(:user)
      game1 = insert(:board_game)
      game2 = insert(:board_game)

      insert(:recommendation_feedback,
        user: user,
        board_game: game1,
        positive: true,
        source: "user_recommendations"
      )

      insert(:recommendation_feedback,
        user: user,
        board_game: game2,
        positive: false,
        source: "similar_games"
      )

      result = Feedback.counts_by_source()

      assert result["user_recommendations"] == %{positive: 1, negative: 0}
      assert result["similar_games"] == %{positive: 0, negative: 1}
    end
  end

  describe "top_games/2" do
    test "returns most liked games" do
      game = insert(:board_game, name: "Popular Game")
      user1 = insert(:user)
      user2 = insert(:user)
      insert(:recommendation_feedback, user: user1, board_game: game, positive: true)
      insert(:recommendation_feedback, user: user2, board_game: game, positive: true)

      result = Feedback.top_games(true)

      assert length(result) == 1
      assert hd(result).name == "Popular Game"
      assert hd(result).count == 2
    end
  end

  describe "recent_feedback/1" do
    test "returns recent feedback with preloaded associations" do
      insert(:recommendation_feedback)

      result = Feedback.recent_feedback()

      assert length(result) == 1
      assert result |> hd() |> Map.get(:user) |> Map.get(:username)
      assert result |> hd() |> Map.get(:board_game) |> Map.get(:name)
    end
  end
end
