defmodule ReccoWeb.Admin.DashboardLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "DashboardLive" do
    test "redirects non-superadmin users", %{conn: conn} do
      user = insert(:user, role: "base")
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")
    end

    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")
    end

    test "renders dashboard for superadmin", %{conn: conn} do
      admin = insert(:user, role: "superadmin")
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/admin")

      assert html =~ "Dashboard"
      assert html =~ "Users"
      assert html =~ "Board Games"
    end
  end
end
