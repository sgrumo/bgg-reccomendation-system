defmodule Recco.Repo.Migrations.CreateUserRatings do
  use Ecto.Migration

  def change do
    create table(:user_ratings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :board_game_id, references(:board_games, type: :binary_id, on_delete: :delete_all),
        null: false

      add :score, :float, null: false
      add :comment, :text

      timestamps(type: :utc_datetime)
    end

    create index(:user_ratings, [:user_id])
    create index(:user_ratings, [:board_game_id])
    create unique_index(:user_ratings, [:user_id, :board_game_id])
  end
end
