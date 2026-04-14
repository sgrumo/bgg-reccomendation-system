defmodule ReccoWeb.WishlistLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Index" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/wishlist")
    end

    test "shows empty state for user with no wishlisted games", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/wishlist")

      assert html =~ "wishlist is empty"
    end

    test "lists wishlisted games", %{conn: conn} do
      user = insert(:user)
      game = insert(:board_game, name: "Catan")
      insert(:user_wishlist, user: user, board_game: game)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/wishlist")

      assert html =~ "Catan"
    end

    test "removes a game from the wishlist", %{conn: conn} do
      user = insert(:user)
      game = insert(:board_game, name: "Catan")
      insert(:user_wishlist, user: user, board_game: game)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/wishlist")

      html =
        view
        |> element("button", "Remove")
        |> render_click()

      refute html =~ "Catan"
    end
  end
end
