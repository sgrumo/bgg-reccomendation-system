defmodule Recco.Repo.Migrations.AddBoardGamesEmbedding do
  use Ecto.Migration

  # Written and queried only by the Python recommender, so the Elixir schema
  # does not declare this field. HNSW index is a separate migration to keep it
  # off the backfill's per-row insert path.
  def change do
    execute "CREATE EXTENSION IF NOT EXISTS vector", ""

    execute(
      "ALTER TABLE board_games ADD COLUMN embedding vector(384)",
      "ALTER TABLE board_games DROP COLUMN embedding"
    )
  end
end
