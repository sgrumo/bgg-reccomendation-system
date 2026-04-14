defmodule Recco.WishlistsTest do
  use Recco.DataCase, async: true

  alias Recco.Wishlists

  describe "add_to_wishlist/2" do
    test "adds a game to the wishlist" do
      user = insert(:user)
      game = insert(:board_game)

      assert {:ok, wishlist} = Wishlists.add_to_wishlist(user.id, game.id)
      assert wishlist.user_id == user.id
      assert wishlist.board_game_id == game.id
    end

    test "returns error when game already wishlisted" do
      user = insert(:user)
      game = insert(:board_game)

      assert {:ok, _} = Wishlists.add_to_wishlist(user.id, game.id)
      assert {:error, :unprocessable_entity, _} = Wishlists.add_to_wishlist(user.id, game.id)
    end
  end

  describe "remove_from_wishlist/2" do
    test "removes a game from the wishlist" do
      wishlist = insert(:user_wishlist)
      assert :ok = Wishlists.remove_from_wishlist(wishlist.user_id, wishlist.board_game_id)
      refute Wishlists.wishlisted?(wishlist.user_id, wishlist.board_game_id)
    end

    test "returns not_found for missing entry" do
      assert {:error, :not_found} =
               Wishlists.remove_from_wishlist(Ecto.UUID.generate(), Ecto.UUID.generate())
    end
  end

  describe "wishlisted?/2" do
    test "returns true when game is wishlisted" do
      wishlist = insert(:user_wishlist)
      assert Wishlists.wishlisted?(wishlist.user_id, wishlist.board_game_id)
    end

    test "returns false when game is not wishlisted" do
      user = insert(:user)
      game = insert(:board_game)
      refute Wishlists.wishlisted?(user.id, game.id)
    end
  end

  describe "list_user_wishlists/1" do
    test "returns user's wishlisted games with preloaded board_game" do
      user = insert(:user)
      game = insert(:board_game, name: "Catan")
      insert(:user_wishlist, user: user, board_game: game)

      wishlists = Wishlists.list_user_wishlists(user.id)

      assert length(wishlists) == 1
      assert hd(wishlists).board_game.name == "Catan"
    end

    test "returns empty list for user with no wishlisted games" do
      user = insert(:user)
      assert Wishlists.list_user_wishlists(user.id) == []
    end
  end

  describe "count_user_wishlists/1" do
    test "returns count of wishlisted games" do
      user = insert(:user)
      game1 = insert(:board_game)
      game2 = insert(:board_game)
      insert(:user_wishlist, user: user, board_game: game1)
      insert(:user_wishlist, user: user, board_game: game2)

      assert Wishlists.count_user_wishlists(user.id) == 2
    end
  end
end
