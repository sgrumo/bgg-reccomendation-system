defmodule ReccoWeb.SearchLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "mount" do
    test "renders the search page with no results before searching", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")

      assert html =~ "Semantic Search"
      refute html =~ "%"
    end
  end

  describe "searching" do
    test "renders enriched results for a query in the URL", %{conn: conn} do
      insert(:board_game, bgg_id: 100, name: "Deep Euro Engine")
      insert(:board_game, bgg_id: 200, name: "Cardboard Cathedral")

      {:ok, view, _html} = live(conn, ~p"/search?q=heavy+strategy")
      html = render_async(view)

      assert html =~ "Deep Euro Engine"
      assert html =~ "Cardboard Cathedral"
      assert html =~ "91%"
    end

    test "falls back to the recommendation name when the game is absent locally",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search?q=heavy+strategy")
      html = render_async(view)

      assert html =~ "Search Result 1"
      assert html =~ "Search Result 2"
    end

    test "submitting the form drives the query through the URL", %{conn: conn} do
      insert(:board_game, bgg_id: 100, name: "Deep Euro Engine")

      {:ok, view, _html} = live(conn, ~p"/search")

      view
      |> form("form", %{q: "engine builder"})
      |> render_submit()

      assert_patch(view, ~p"/search?q=engine+builder")
      assert render_async(view) =~ "Deep Euro Engine"
    end
  end
end
