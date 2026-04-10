defmodule ReccoWeb.RatingLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Index" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/ratings")
    end

    test "shows empty state for user with no ratings", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/ratings")

      assert html =~ "haven&#39;t rated"
    end

    test "lists user ratings", %{conn: conn} do
      user = insert(:user)
      game = insert(:board_game, name: "Catan")
      insert(:user_rating, user: user, board_game: game, score: 8.0)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/ratings")

      assert html =~ "Catan"
      assert html =~ "8.0"
    end
  end
end
