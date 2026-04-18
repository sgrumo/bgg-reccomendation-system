defmodule Recco.Accounts.SoftDeleteTest do
  use Recco.DataCase, async: true

  alias Recco.Accounts

  describe "soft_delete_user/1" do
    test "anonymizes PII and marks the tombstone" do
      user = insert(:user, email: "real@example.com", username: "realname")

      assert {:ok, tombstone} = Accounts.soft_delete_user(user)

      assert tombstone.deleted_at
      assert tombstone.email != "real@example.com"
      assert tombstone.email =~ "@invalid.local"
      assert tombstone.username =~ "deleted_"
      refute tombstone.hashed_password == user.hashed_password
    end

    test "refuses to delete a superadmin" do
      admin = insert(:user, role: "superadmin")
      assert {:error, :forbidden} = Accounts.soft_delete_user(admin)
    end

    test "is idempotent-safe: refuses to re-delete" do
      user = insert(:user)
      {:ok, tombstone} = Accounts.soft_delete_user(user)

      assert {:error, :already_deleted} = Accounts.soft_delete_user(tombstone)
    end

    test "wipes user_tokens so session-based lookups stop resolving" do
      user = insert(:user)
      token = Accounts.generate_user_session_token(user)
      assert Accounts.get_user_by_session_token(token)

      {:ok, _} = Accounts.soft_delete_user(user)

      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "lookups" do
    test "get_user_by_email hides soft-deleted users" do
      user = insert(:user, email: "bye@example.com")
      {:ok, _} = Accounts.soft_delete_user(user)

      refute Accounts.get_user_by_email("bye@example.com")
    end

    test "get_user_by_id hides soft-deleted users" do
      user = insert(:user)
      {:ok, _} = Accounts.soft_delete_user(user)

      refute Accounts.get_user_by_id(user.id)
    end

    test "admin_get_user_by_id still returns the tombstone" do
      user = insert(:user)
      {:ok, tombstone} = Accounts.soft_delete_user(user)

      found = Accounts.admin_get_user_by_id(user.id)
      assert found.id == tombstone.id
      assert found.deleted_at
    end

    test "authenticate_user_by_email refuses soft-deleted users" do
      user = insert(:user, email: "loginfail@example.com")
      {:ok, _} = Accounts.soft_delete_user(user)

      assert {:error, :unauthorized} =
               Accounts.authenticate_user_by_email("loginfail@example.com", "valid_password123")
    end
  end

  describe "list_users/1" do
    test "excludes soft-deleted by default" do
      active = insert(:user)
      deleted = insert(:user)
      {:ok, _} = Accounts.soft_delete_user(deleted)

      %{users: rows} = Accounts.list_users()
      ids = Enum.map(rows, & &1.user.id)

      assert active.id in ids
      refute deleted.id in ids
    end

    test "include_deleted: true surfaces soft-deleted users" do
      active = insert(:user)
      deleted = insert(:user)
      {:ok, _} = Accounts.soft_delete_user(deleted)

      %{users: rows} = Accounts.list_users(%{include_deleted: true})
      ids = Enum.map(rows, & &1.user.id)

      assert active.id in ids
      assert deleted.id in ids
    end
  end

  describe "restore_user/1" do
    test "clears deleted_at for a recently soft-deleted user" do
      user = insert(:user)
      {:ok, tombstone} = Accounts.soft_delete_user(user)

      assert {:ok, restored} = Accounts.restore_user(tombstone)
      refute restored.deleted_at
    end

    test "refuses when the user was never deleted" do
      user = insert(:user)
      assert {:error, :not_deleted} = Accounts.restore_user(user)
    end

    test "refuses past the 30-day window" do
      user =
        insert(:user,
          deleted_at: DateTime.utc_now() |> DateTime.add(-40 * 24 * 60 * 60, :second)
        )

      assert {:error, :window_expired} = Accounts.restore_user(user)
    end
  end

  describe "hard_delete_user/1" do
    test "removes the row and cascades" do
      user = insert(:user)
      _ = Accounts.generate_user_session_token(user)

      assert {:ok, _} = Accounts.hard_delete_user(user)
      refute Accounts.admin_get_user_by_id(user.id)
    end

    test "refuses for superadmin" do
      admin = insert(:user, role: "superadmin")
      assert {:error, :forbidden} = Accounts.hard_delete_user(admin)
    end
  end
end
