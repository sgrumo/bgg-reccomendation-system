defmodule ReccoWeb.GameLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Index" do
    test "renders browse page with games", %{conn: conn} do
      insert(:board_game, name: "Catan")

      {:ok, _view, html} = live(conn, ~p"/games")

      assert html =~ "Browse Games"
      assert html =~ "Catan"
    end

    test "searches games by name", %{conn: conn} do
      insert(:board_game, name: "Catan")
      insert(:board_game, name: "Pandemic")

      {:ok, view, _html} = live(conn, ~p"/games")

      view
      |> element("form[phx-change=search]")
      |> render_change(%{"search" => "Pandemic"})

      assert_patch(view, ~p"/games?search=Pandemic")
    end

    test "paginates via URL params", %{conn: conn} do
      for i <- 1..30, do: insert(:board_game, name: "Game #{i}")

      {:ok, _view, html} = live(conn, ~p"/games")

      assert html =~ "30 games found"
      assert html =~ "Next"
    end

    test "shows empty state when no games match", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/games?search=nonexistent")

      assert html =~ "No games found"
    end
  end

  describe "Show" do
    test "renders game detail page", %{conn: conn} do
      game = insert(:board_game, name: "Catan", year_published: 1995, average_rating: 7.2)

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")

      assert html =~ "Catan"
      assert html =~ "1995"
      assert html =~ "7.2"
    end

    test "redirects for unknown game id", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/games"}}} =
               live(conn, ~p"/games/#{Ecto.UUID.generate()}")
    end
  end
end
