defmodule Recco.Repo.Migrations.CreateUsersAndUserTokens do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :username, :string, null: false
      add :hashed_password, :string, null: false
      add :role, :string, null: false, default: "base"
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])

    create table(:user_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:user_tokens, [:user_id])
    create unique_index(:user_tokens, [:context, :token])
  end
end
