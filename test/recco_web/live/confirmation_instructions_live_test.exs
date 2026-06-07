defmodule ReccoWeb.ConfirmationInstructionsLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Recco.Accounts.UserToken
  alias Recco.Repo

  describe "ConfirmationInstructionsLive" do
    test "renders the resend form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/confirm")
      assert html =~ "Confirm your email"
      assert html =~ "Send confirmation link"
    end

    test "sends a confirmation email when the user exists and is unconfirmed", %{conn: conn} do
      user = insert(:user, email: "pending@example.com", confirmed_at: nil)

      {:ok, view, _html} = live(conn, ~p"/confirm")

      assert {:error, {:redirect, %{to: "/login"}}} =
               view |> form("form", user: %{email: user.email}) |> render_submit()

      assert_email_sent(fn email -> assert email.subject == "Confirm your email" end)
      assert Repo.get_by(UserToken, user_id: user.id, context: "confirm")
    end

    test "redirects logged-in users to / after submit", %{conn: conn} do
      user = insert(:user, email: "pending@example.com", confirmed_at: nil)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/confirm")

      assert {:error, {:redirect, %{to: "/"}}} =
               view |> form("form", user: %{email: user.email}) |> render_submit()
    end

    test "does not send when the email does not match any user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/confirm")

      assert {:error, {:redirect, %{to: "/login"}}} =
               view |> form("form", user: %{email: "nobody@example.com"}) |> render_submit()

      assert_no_email_sent()
      assert Repo.aggregate(UserToken, :count) == 0
    end

    test "does not send when the user is already confirmed", %{conn: conn} do
      user =
        insert(:user,
          email: "confirmed@example.com",
          confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      {:ok, view, _html} = live(conn, ~p"/confirm")

      assert {:error, {:redirect, %{to: "/login"}}} =
               view |> form("form", user: %{email: user.email}) |> render_submit()

      assert_no_email_sent()
      assert Repo.aggregate(UserToken, :count) == 0
    end
  end
end
