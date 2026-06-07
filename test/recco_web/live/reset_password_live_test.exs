defmodule ReccoWeb.ResetPasswordLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Recco.Accounts
  alias Recco.Accounts.User
  alias Recco.Accounts.UserToken
  alias Recco.Repo

  defp put_token(user) do
    {encoded, user_token} = UserToken.build_reset_password_token(user)
    Repo.insert!(user_token)
    encoded
  end

  describe "mount" do
    test "redirects when the token is malformed", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} =
               live(conn, ~p"/reset-password/not-a-token")
    end

    test "redirects when the token is expired", %{conn: conn} do
      user = insert(:user)
      token = put_token(user)

      # Backdate the token past the 1-hour validity window.
      Repo.update_all(UserToken,
        set: [inserted_at: DateTime.utc_now() |> DateTime.add(-2, :hour)]
      )

      assert {:error, {:redirect, %{to: "/login"}}} =
               live(conn, ~p"/reset-password/#{token}")
    end

    test "renders the reset form for a valid token", %{conn: conn} do
      user = insert(:user)
      token = put_token(user)

      {:ok, _view, html} = live(conn, ~p"/reset-password/#{token}")

      assert html =~ "Reset password"
      assert html =~ "New password"
    end
  end

  describe "reset" do
    test "updates the password and wipes all user tokens on success", %{conn: conn} do
      user = insert(:user)
      token = put_token(user)
      # Extra session token to confirm reset wipes ALL tokens, not just the reset one.
      _session_token = Accounts.generate_user_session_token(user)

      {:ok, view, _html} = live(conn, ~p"/reset-password/#{token}")

      result =
        view
        |> form("form", user: %{password: "brand-new-password"})
        |> render_submit()

      assert {:error, {:redirect, %{to: "/login"}}} = result

      updated = Repo.get!(User, user.id)
      assert User.valid_password?(updated, "brand-new-password")

      assert Repo.aggregate(from(t in UserToken, where: t.user_id == ^user.id), :count) == 0
    end

    test "renders validation errors for an invalid password", %{conn: conn} do
      user = insert(:user)
      token = put_token(user)

      {:ok, view, _html} = live(conn, ~p"/reset-password/#{token}")

      html =
        view
        |> form("form", user: %{password: "short"})
        |> render_submit()

      assert html =~ "should be at least 8 character"
    end
  end
end
