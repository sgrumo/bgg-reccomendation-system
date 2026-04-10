defmodule Recco.Repo.Migrations.AddBoardGamesSearchIndexes do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", ""

    execute(
      "CREATE INDEX board_games_name_trgm_index ON board_games USING gin (name gin_trgm_ops)",
      "DROP INDEX board_games_name_trgm_index"
    )

    execute(
      "CREATE INDEX board_games_categories_gin_index ON board_games USING gin (categories jsonb_path_ops)",
      "DROP INDEX board_games_categories_gin_index"
    )

    execute(
      "CREATE INDEX board_games_mechanics_gin_index ON board_games USING gin (mechanics jsonb_path_ops)",
      "DROP INDEX board_games_mechanics_gin_index"
    )
  end
end
