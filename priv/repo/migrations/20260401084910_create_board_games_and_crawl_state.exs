defmodule Recco.Repo.Migrations.CreateBoardGamesAndCrawlState do
  use Ecto.Migration

  def change do
    create table(:board_games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :bgg_id, :integer, null: false
      add :name, :string
      add :alternate_names, {:array, :string}, default: []
      add :description, :text
      add :year_published, :integer
      add :min_players, :integer
      add :max_players, :integer
      add :min_playtime, :integer
      add :max_playtime, :integer
      add :playing_time, :integer
      add :min_age, :integer
      add :image_url, :string
      add :thumbnail_url, :string
      add :average_rating, :float
      add :bayes_average_rating, :float
      add :users_rated, :integer
      add :average_weight, :float
      add :categories, :jsonb, default: "[]"
      add :mechanics, :jsonb, default: "[]"
      add :designers, :jsonb, default: "[]"
      add :artists, :jsonb, default: "[]"
      add :publishers, :jsonb, default: "[]"
      add :families, :jsonb, default: "[]"
      add :ranks, :jsonb, default: "[]"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:board_games, [:bgg_id])
    create index(:board_games, [:average_rating])
    create index(:board_games, [:bayes_average_rating])

    create table(:crawl_state, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :last_fetched_id, :integer, default: 0
      add :status, :string, default: "idle"
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:crawl_state, [:key])
  end
end
