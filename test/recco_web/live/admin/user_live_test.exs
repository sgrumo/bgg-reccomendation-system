defmodule ReccoWeb.Admin.UserLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    admin = insert(:user, role: "superadmin")
    conn = log_in_user(conn, admin)
    {:ok, conn: conn, admin: admin}
  end

  describe "Index" do
    test "lists users", %{conn: conn, admin: admin} do
      insert(:user, username: "testuser1")

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "Users"
      assert html =~ admin.username
      assert html =~ "testuser1"
    end

    test "searches users", %{conn: conn} do
      insert(:user, username: "findme", email: "findme@example.com")
      insert(:user, username: "other", email: "other@example.com")

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view
      |> element("form[phx-change=search]")
      |> render_change(%{"search" => "findme"})

      assert_patch(view, ~p"/admin/users?search=findme")
    end
  end

  describe "Show" do
    test "shows user details", %{conn: conn} do
      user = insert(:user, username: "detailuser", email: "detail@example.com")

      {:ok, _view, html} = live(conn, ~p"/admin/users/#{user.id}")

      assert html =~ "detailuser"
      assert html =~ "detail@example.com"
    end

    test "shows user ratings", %{conn: conn} do
      user = insert(:user)
      game = insert(:board_game, name: "RatedGame")
      insert(:user_rating, user: user, board_game: game, score: 9.0)

      {:ok, _view, html} = live(conn, ~p"/admin/users/#{user.id}")

      assert html =~ "RatedGame"
      assert html =~ "9.0"
    end

    test "shows user stats", %{conn: conn} do
      user = insert(:user)
      game = insert(:board_game)
      insert(:user_rating, user: user, board_game: game, score: 8.0)

      {:ok, _view, html} = live(conn, ~p"/admin/users/#{user.id}")

      assert html =~ "Avg Score"
      assert html =~ "Highest"
    end

    test "deletes a base user", %{conn: conn} do
      user = insert(:user, role: "base")

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{user.id}")

      view
      |> element("button", "Delete user")
      |> render_click()

      assert_redirect(view, ~p"/admin/users")
    end

    test "cannot delete a superadmin", %{conn: conn} do
      admin = insert(:user, role: "superadmin")

      {:ok, _view, html} = live(conn, ~p"/admin/users/#{admin.id}")

      refute html =~ "Delete user"
    end

    test "redirects for unknown user", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/users"}}} =
               live(conn, ~p"/admin/users/#{Ecto.UUID.generate()}")
    end
  end
end
