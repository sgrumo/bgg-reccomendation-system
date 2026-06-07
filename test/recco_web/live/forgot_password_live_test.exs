defmodule ReccoWeb.ForgotPasswordLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Recco.Accounts.UserToken
  alias Recco.Repo

  describe "ForgotPasswordLive" do
    test "redirects authenticated users to /", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/forgot-password")
    end

    test "renders the request form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/forgot-password")

      assert html =~ "Forgot your password?"
      assert html =~ "Send reset link"
    end

    test "sends a reset email when the email belongs to a user", %{conn: conn} do
      user = insert(:user, email: "exists@example.com")

      {:ok, view, _html} = live(conn, ~p"/forgot-password")

      result =
        view
        |> form("form", user: %{email: user.email})
        |> render_submit()

      assert {:error, {:redirect, %{to: "/login"}}} = result

      assert_email_sent(fn email ->
        assert email.to == [{"", user.email}]
        assert email.subject == "Reset your password"
      end)

      assert Repo.get_by(UserToken, user_id: user.id, context: "reset_password")
    end

    test "does not reveal whether the email exists when no user matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/forgot-password")

      result =
        view
        |> form("form", user: %{email: "nobody@example.com"})
        |> render_submit()

      assert {:error, {:redirect, %{to: "/login"}}} = result

      assert_no_email_sent()
      assert Repo.aggregate(UserToken, :count) == 0
    end
  end
end
