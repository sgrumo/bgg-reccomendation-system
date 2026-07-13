defmodule Recco.Repo.Migrations.AddBoardGamesEmbeddingFreshnessTrigger do
  use Ecto.Migration

  # Nulls the embedding whenever any field that feeds it changes, so the next
  # backfill re-embeds the row. Unchanged re-crawls leave the embedding intact,
  # avoiding needless churn. New rows already start with a NULL embedding.
  def up do
    execute("""
    CREATE OR REPLACE FUNCTION recco_clear_stale_embedding()
    RETURNS trigger AS $$
    BEGIN
      IF NEW.name IS DISTINCT FROM OLD.name
         OR NEW.description IS DISTINCT FROM OLD.description
         OR NEW.categories IS DISTINCT FROM OLD.categories
         OR NEW.mechanics IS DISTINCT FROM OLD.mechanics THEN
        NEW.embedding := NULL;
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER board_games_clear_stale_embedding
      BEFORE UPDATE ON board_games
      FOR EACH ROW EXECUTE FUNCTION recco_clear_stale_embedding()
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS board_games_clear_stale_embedding ON board_games")
    execute("DROP FUNCTION IF EXISTS recco_clear_stale_embedding()")
  end
end
