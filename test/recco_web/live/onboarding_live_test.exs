defmodule ReccoWeb.OnboardingLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Recco.Accounts
  alias Recco.Ratings

  describe "OnboardingLive" do
    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/onboarding")
    end

    test "redirects already-onboarded users to /", %{conn: conn} do
      user = insert(:user, onboarded_at: DateTime.utc_now() |> DateTime.truncate(:second))
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/onboarding")
    end

    test "renders onboarding for a fresh user", %{conn: conn} do
      insert(:board_game,
        name: "Popular Game",
        bayes_average_rating: 7.5,
        users_rated: 50_000
      )

      user = insert(:user, onboarded_at: nil)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/onboarding")

      assert html =~ "Welcome"
      assert html =~ "Popular Game"
      assert html =~ "Skip for now"
    end

    test "rate event persists a rating and updates the UI", %{conn: conn} do
      game =
        insert(:board_game,
          name: "Rateable",
          bayes_average_rating: 7.2,
          users_rated: 10_000
        )

      user = insert(:user, onboarded_at: nil)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/onboarding")

      html =
        view
        |> render_click("rate", %{"game-id" => game.id, "score" => "8"})

      assert html =~ "8/10"
      assert Ratings.get_user_rating(user.id, game.id).score == 8.0
    end

    test "dismiss hides a card from the grid", %{conn: conn} do
      game =
        insert(:board_game,
          name: "DismissMe",
          bayes_average_rating: 7.0,
          users_rated: 5_000
        )

      user = insert(:user, onboarded_at: nil)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/onboarding")
      assert render(view) =~ "DismissMe"

      html = render_click(view, "dismiss", %{"game-id" => game.id})
      refute html =~ "DismissMe"
    end

    test "skip marks onboarded and redirects to /", %{conn: conn} do
      user = insert(:user, onboarded_at: nil)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/onboarding")

      assert {:error, {:redirect, %{to: "/"}}} = render_click(view, "skip")
      assert Accounts.get_user_by_id(user.id).onboarded_at
    end

    test "finish with no ratings redirects to /games and marks onboarded", %{conn: conn} do
      user = insert(:user, onboarded_at: nil)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/onboarding")

      assert {:error, {:redirect, %{to: "/games"}}} = render_click(view, "finish")
      assert Accounts.get_user_by_id(user.id).onboarded_at
    end

    test "search swaps popular picks with FTS results", %{conn: conn} do
      _popular =
        insert(:board_game,
          name: "Popular Default",
          bayes_average_rating: 7.5,
          users_rated: 50_000
        )

      _searchable =
        insert(:board_game,
          name: "Wingspan",
          bayes_average_rating: 6.9,
          users_rated: 800
        )

      user = insert(:user, onboarded_at: nil)
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/onboarding")
      assert html =~ "Popular Default"
      refute html =~ "Wingspan"

      html =
        view
        |> form("form[phx-change=search]", search: "Wingspan")
        |> render_change()

      assert html =~ "Wingspan"
      assert html =~ "Showing results"
    end

    test "search with no matches shows empty-result note", %{conn: conn} do
      user = insert(:user, onboarded_at: nil)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/onboarding")

      html =
        view
        |> form("form[phx-change=search]", search: "Zzzz_no_such_game_zzzz")
        |> render_change()

      assert html =~ "No games match"
    end

    test "finish with at least one rating redirects to /recommendations", %{conn: conn} do
      game =
        insert(:board_game,
          name: "Finish Game",
          bayes_average_rating: 7.5,
          users_rated: 20_000
        )

      user = insert(:user, onboarded_at: nil)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/onboarding")
      _ = render_click(view, "rate", %{"game-id" => game.id, "score" => "9"})

      assert {:error, {:redirect, %{to: "/recommendations"}}} = render_click(view, "finish")
    end
  end
end
