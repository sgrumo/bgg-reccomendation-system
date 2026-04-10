defmodule ReccoWeb.PreferenceLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Edit" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/preferences")
    end

    test "renders preferences form", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/preferences")

      assert html =~ "Preferences"
      assert html =~ "Save preferences"
    end

    test "saves preferences", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/preferences")

      view
      |> form("form", user_preference: %{min_players: 2, max_players: 5})
      |> render_submit()

      assert render(view) =~ "Preferences saved!"
    end
  end
end
