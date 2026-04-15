defmodule Recco.Repo.Migrations.CreateRecommendationFeedback do
  use Ecto.Migration

  def change do
    create table(:recommendation_feedback, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :board_game_id, references(:board_games, type: :binary_id, on_delete: :delete_all),
        null: false

      add :positive, :boolean, null: false
      add :source, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:recommendation_feedback, [:user_id])
    create index(:recommendation_feedback, [:board_game_id])
    create unique_index(:recommendation_feedback, [:user_id, :board_game_id])
  end
end
