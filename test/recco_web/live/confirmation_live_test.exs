defmodule ReccoWeb.ConfirmationLiveTest do
  use ReccoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Recco.Accounts.User
  alias Recco.Accounts.UserToken
  alias Recco.Repo

  defp put_confirm_token(user) do
    {encoded, user_token} = UserToken.build_confirm_token(user)
    Repo.insert!(user_token)
    encoded
  end

  describe "ConfirmationLive" do
    test "confirms the user and redirects to /login for anonymous visitors", %{conn: conn} do
      user = insert(:user, confirmed_at: nil)
      token = put_confirm_token(user)

      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/confirm/#{token}")

      assert %DateTime{} = Repo.get!(User, user.id).confirmed_at
    end

    test "confirms the user and redirects to / for logged-in visitors", %{conn: conn} do
      user = insert(:user, confirmed_at: nil)
      token = put_confirm_token(user)
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/confirm/#{token}")
      assert %DateTime{} = Repo.get!(User, user.id).confirmed_at
    end

    test "redirects to /confirm with an error when the token is malformed", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/confirm"}}} =
               live(conn, ~p"/confirm/not-a-token")
    end

    test "redirects to /confirm with an error when the token is expired", %{conn: conn} do
      user = insert(:user, confirmed_at: nil)
      token = put_confirm_token(user)

      Repo.update_all(UserToken,
        set: [inserted_at: DateTime.utc_now() |> DateTime.add(-8, :day)]
      )

      assert {:error, {:redirect, %{to: "/confirm"}}} = live(conn, ~p"/confirm/#{token}")
      assert is_nil(Repo.get!(User, user.id).confirmed_at)
    end
  end
end
