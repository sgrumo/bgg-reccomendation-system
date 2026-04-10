defmodule Recco.RatingsTest do
  use Recco.DataCase, async: true

  alias Recco.Ratings

  describe "rate_game/3" do
    test "creates a new rating" do
      user = insert(:user)
      game = insert(:board_game)

      assert {:ok, rating} = Ratings.rate_game(user.id, game.id, %{score: 8.0})
      assert rating.score == 8.0
      assert rating.user_id == user.id
      assert rating.board_game_id == game.id
    end

    test "updates an existing rating" do
      user = insert(:user)
      game = insert(:board_game)

      assert {:ok, _} = Ratings.rate_game(user.id, game.id, %{score: 6.0})
      assert {:ok, rating} = Ratings.rate_game(user.id, game.id, %{score: 9.0})
      assert rating.score == 9.0
    end

    test "validates score range" do
      user = insert(:user)
      game = insert(:board_game)

      assert {:error, :unprocessable_entity, _} =
               Ratings.rate_game(user.id, game.id, %{score: 11.0})

      assert {:error, :unprocessable_entity, _} =
               Ratings.rate_game(user.id, game.id, %{score: 0.0})
    end
  end

  describe "delete_rating/2" do
    test "deletes an existing rating" do
      rating = insert(:user_rating)
      assert :ok = Ratings.delete_rating(rating.user_id, rating.board_game_id)
      assert is_nil(Ratings.get_user_rating(rating.user_id, rating.board_game_id))
    end

    test "returns not_found for missing rating" do
      assert {:error, :not_found} =
               Ratings.delete_rating(Ecto.UUID.generate(), Ecto.UUID.generate())
    end
  end

  describe "list_user_ratings/1" do
    test "returns user's ratings with preloaded games" do
      user = insert(:user)
      game = insert(:board_game, name: "TestGame")
      insert(:user_rating, user: user, board_game: game, score: 7.0)

      ratings = Ratings.list_user_ratings(user.id)

      assert length(ratings) == 1
      assert hd(ratings).board_game.name == "TestGame"
    end

    test "returns empty list for user with no ratings" do
      user = insert(:user)
      assert Ratings.list_user_ratings(user.id) == []
    end
  end

  describe "user_ratings_as_map/1" do
    test "returns bgg_id => score map" do
      user = insert(:user)
      game = insert(:board_game, bgg_id: 42)
      insert(:user_rating, user: user, board_game: game, score: 8.5)

      result = Ratings.user_ratings_as_map(user.id)
      assert result == %{42 => 8.5}
    end
  end
end
