defmodule Recco.AccountsTest do
  use Recco.DataCase, async: true

  alias Recco.Accounts
  alias Recco.Accounts.User
  alias Recco.Accounts.UserToken

  describe "register_user/1" do
    test "creates a user with valid attrs" do
      attrs = %{email: "new@example.com", username: "newuser", password: "valid_password123"}
      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.email == "new@example.com"
      assert user.username == "newuser"
      assert user.hashed_password
      assert user.role == "base"
    end

    test "returns error for invalid attrs" do
      assert {:error, :unprocessable_entity, errors} = Accounts.register_user(%{})
      assert Map.has_key?(errors, :email)
    end
  end

  describe "authenticate_user_by_email/2" do
    test "returns user for valid credentials" do
      user = insert(:user, email: "auth@example.com")

      assert {:ok, found} =
               Accounts.authenticate_user_by_email("auth@example.com", "valid_password123")

      assert found.id == user.id
    end

    test "returns error for wrong password" do
      insert(:user, email: "auth@example.com")

      assert {:error, :unauthorized} =
               Accounts.authenticate_user_by_email("auth@example.com", "wrong")
    end

    test "returns error for non-existent email" do
      assert {:error, :unauthorized} =
               Accounts.authenticate_user_by_email("nope@example.com", "any")
    end
  end

  describe "session tokens" do
    test "generate and verify session token" do
      user = insert(:user)
      token = Accounts.generate_user_session_token(user)

      found = Accounts.get_user_by_session_token(token)
      assert found.id == user.id
    end

    test "returns nil for invalid token" do
      assert is_nil(Accounts.get_user_by_session_token(:crypto.strong_rand_bytes(32)))
    end

    test "delete_user_session_token invalidates the token" do
      user = insert(:user)
      token = Accounts.generate_user_session_token(user)

      Accounts.delete_user_session_token(token)
      assert is_nil(Accounts.get_user_by_session_token(token))
    end
  end

  describe "get_user_by_email/1" do
    test "returns user by email" do
      user = insert(:user, email: "find@example.com")
      found = Accounts.get_user_by_email("find@example.com")
      assert found.id == user.id
    end

    test "returns nil for unknown email" do
      assert is_nil(Accounts.get_user_by_email("nope@example.com"))
    end
  end

  describe "get_user_by_id/1" do
    test "returns user by id" do
      user = insert(:user)
      found = Accounts.get_user_by_id(user.id)
      assert found.id == user.id
    end

    test "returns nil for unknown id" do
      assert is_nil(Accounts.get_user_by_id(Ecto.UUID.generate()))
    end
  end

  describe "mark_onboarded/1" do
    test "sets onboarded_at for a new user" do
      user = insert(:user, onboarded_at: nil)
      assert {:ok, updated} = Accounts.mark_onboarded(user)
      assert %DateTime{} = updated.onboarded_at
    end

    test "is idempotent for already-onboarded users" do
      original_at =
        DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-3600, :second)

      user = insert(:user, onboarded_at: original_at)
      assert {:ok, updated} = Accounts.mark_onboarded(user)
      assert DateTime.compare(updated.onboarded_at, original_at) == :eq
    end
  end

  describe "set_user_role/2" do
    test "promotes a base user to superadmin" do
      user = insert(:user, role: "base")
      assert {:ok, updated} = Accounts.set_user_role(user, "superadmin")
      assert updated.role == "superadmin"
    end

    test "demotes a superadmin to base" do
      user = insert(:user, role: "superadmin")
      assert {:ok, updated} = Accounts.set_user_role(user, "base")
      assert updated.role == "base"
    end

    test "rejects an unknown role" do
      user = insert(:user, role: "base")

      assert {:error, :unprocessable_entity, errors} =
               Accounts.set_user_role(user, "wizard")

      assert errors[:role]
    end

    test "refuses to change the role of a soft-deleted user" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      user = insert(:user, role: "base", deleted_at: now)
      assert {:error, :forbidden} = Accounts.set_user_role(user, "superadmin")
    end
  end

  describe "confirmed?/1" do
    test "is false when confirmed_at is nil" do
      refute Accounts.confirmed?(%User{confirmed_at: nil})
    end

    test "is true when confirmed_at is set" do
      assert Accounts.confirmed?(%User{confirmed_at: DateTime.utc_now()})
    end
  end

  describe "deliver_confirmation_instructions/2" do
    import Swoosh.TestAssertions

    test "inserts a confirm token and sends the confirmation email" do
      user = insert(:user, confirmed_at: nil)

      assert {:ok, _meta} =
               Accounts.deliver_confirmation_instructions(user, fn token ->
                 "https://x/#{token}"
               end)

      assert_email_sent(fn email -> assert email.subject == "Confirm your email" end)

      assert Repo.get_by(UserToken, user_id: user.id, context: "confirm")
    end

    test "refuses to deliver when the user is already confirmed" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      user = insert(:user, confirmed_at: now)

      assert {:error, :already_confirmed} =
               Accounts.deliver_confirmation_instructions(user, fn token ->
                 "https://x/#{token}"
               end)

      assert_no_email_sent()
      refute Repo.get_by(UserToken, user_id: user.id, context: "confirm")
    end
  end

  describe "confirm_user_by_token/1" do
    test "sets confirmed_at and deletes the confirm tokens for that user" do
      user = insert(:user, confirmed_at: nil)

      {encoded, user_token} = UserToken.build_confirm_token(user)
      Repo.insert!(user_token)

      assert {:ok, confirmed} = Accounts.confirm_user_by_token(encoded)
      assert confirmed.id == user.id
      assert %DateTime{} = confirmed.confirmed_at

      assert Repo.aggregate(
               from(t in UserToken,
                 where: t.user_id == ^user.id and t.context == "confirm"
               ),
               :count
             ) == 0
    end

    test "leaves non-confirm tokens (e.g. session tokens) intact" do
      user = insert(:user, confirmed_at: nil)
      _session = Accounts.generate_user_session_token(user)

      {encoded, user_token} = UserToken.build_confirm_token(user)
      Repo.insert!(user_token)

      assert {:ok, _} = Accounts.confirm_user_by_token(encoded)

      assert Repo.aggregate(
               from(t in UserToken,
                 where: t.user_id == ^user.id and t.context == "session"
               ),
               :count
             ) == 1
    end

    test "returns :invalid_token for a malformed token" do
      assert {:error, :invalid_token} = Accounts.confirm_user_by_token("not-a-token")
    end

    test "returns :invalid_token for an expired token" do
      user = insert(:user, confirmed_at: nil)

      {encoded, user_token} = UserToken.build_confirm_token(user)
      Repo.insert!(user_token)

      # Backdate the token past the 7-day window.
      Repo.update_all(UserToken,
        set: [inserted_at: DateTime.utc_now() |> DateTime.add(-8, :day)]
      )

      assert {:error, :invalid_token} = Accounts.confirm_user_by_token(encoded)
    end
  end
end
