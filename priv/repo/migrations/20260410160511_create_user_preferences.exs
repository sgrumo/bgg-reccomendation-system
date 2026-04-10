defmodule Recco.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :preferred_categories, :jsonb, default: "[]"
      add :preferred_mechanics, :jsonb, default: "[]"
      add :min_players, :integer
      add :max_players, :integer
      add :min_weight, :float
      add :max_weight, :float
      add :min_playtime, :integer
      add :max_playtime, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_preferences, [:user_id])
  end
end
