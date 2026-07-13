defmodule Recco.Repo.Migrations.AddBoardGamesEmbeddingHnswIndex do
  use Ecto.Migration

  # CREATE INDEX CONCURRENTLY cannot run inside a transaction, and the Ecto
  # migration lock must be skipped for the same reason. On the full table the
  # HNSW build is heavy; CONCURRENTLY keeps writes unblocked while it runs.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS board_games_embedding_hnsw_idx
      ON board_games USING hnsw (embedding vector_cosine_ops)
    """)
  end

  def down do
    execute("DROP INDEX CONCURRENTLY IF EXISTS board_games_embedding_hnsw_idx")
  end
end
