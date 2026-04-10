defmodule Recco.Accounts.UserTest do
  use Recco.DataCase, async: true

  alias Recco.Accounts.User

  describe "registration_changeset/2" do
    test "valid attrs produces a valid changeset" do
      attrs = %{email: "test@example.com", username: "testuser", password: "valid_password123"}
      changeset = User.registration_changeset(%User{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :hashed_password)
      refute get_change(changeset, :password)
    end

    test "requires email, username, and password" do
      changeset = User.registration_changeset(%User{}, %{})

      assert "can't be blank" in errors_on(changeset).email
      assert "can't be blank" in errors_on(changeset).username
      assert "can't be blank" in errors_on(changeset).password
    end

    test "validates email format" do
      changeset = User.registration_changeset(%User{}, %{email: "nope"})
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "validates username format" do
      changeset = User.registration_changeset(%User{}, %{username: "has spaces"})
      assert "only letters, numbers, and underscores" in errors_on(changeset).username
    end

    test "validates password length" do
      changeset = User.registration_changeset(%User{}, %{password: "short"})
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      insert(:user, email: "taken@example.com")

      {:error, changeset} =
        %User{}
        |> User.registration_changeset(%{
          email: "taken@example.com",
          username: "new",
          password: "valid_password123"
        })
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates username uniqueness" do
      insert(:user, username: "taken")

      {:error, changeset} =
        %User{}
        |> User.registration_changeset(%{
          email: "new@example.com",
          username: "taken",
          password: "valid_password123"
        })
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).username
    end
  end

  describe "valid_password?/2" do
    test "returns true for valid password" do
      user = insert(:user)
      assert User.valid_password?(user, "valid_password123")
    end

    test "returns false for invalid password" do
      user = insert(:user)
      refute User.valid_password?(user, "wrong")
    end

    test "returns false for nil user" do
      refute User.valid_password?(nil, "any")
    end
  end

  describe "superadmin?/1" do
    test "returns true for superadmin" do
      assert User.superadmin?(%User{role: "superadmin"})
    end

    test "returns false for base user" do
      refute User.superadmin?(%User{role: "base"})
    end
  end
end
