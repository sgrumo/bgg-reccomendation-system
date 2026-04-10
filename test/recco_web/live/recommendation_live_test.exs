defmodule ReccoWeb.RecommendationLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Index" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/recommendations")
    end

    test "renders recommendations page for authenticated user", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/recommendations")

      assert html =~ "Recommendations"
    end
  end
end
