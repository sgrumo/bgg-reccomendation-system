defmodule ReccoWeb.Admin.FeedbackLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "FeedbackLive" do
    test "redirects non-superadmin users", %{conn: conn} do
      user = insert(:user, role: "base")
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/feedback")
    end

    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/feedback")
    end

    test "renders feedback page for superadmin", %{conn: conn} do
      admin = insert(:user, role: "superadmin")
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/admin/feedback")

      assert html =~ "Recommendation Feedback"
      assert html =~ "Total Feedback"
      assert html =~ "Positive Rate"
    end

    test "displays feedback data", %{conn: conn} do
      admin = insert(:user, role: "superadmin")
      user = insert(:user)
      game = insert(:board_game, name: "Catan")
      insert(:recommendation_feedback, user: user, board_game: game, positive: true)
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/admin/feedback")

      assert html =~ "Catan"
      assert html =~ "Positive"
    end
  end
end
