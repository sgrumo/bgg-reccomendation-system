defmodule Recco.Repo.Migrations.AddBoardGamesSearchVector do
  use Ecto.Migration

  # CREATE INDEX CONCURRENTLY cannot run inside a transaction, and we
  # must also skip the Ecto migration lock for the same reason.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS unaccent")

    # PostgreSQL requires expressions in generated columns to be IMMUTABLE.
    # `unaccent/1` is STABLE by default because it reads the current
    # dictionary; wrapping it with an explicit dictionary argument and
    # declaring IMMUTABLE makes it usable in a generated column.
    execute("""
    CREATE OR REPLACE FUNCTION recco_immutable_unaccent(text)
    RETURNS text AS $$
      SELECT unaccent('unaccent', $1)
    $$ LANGUAGE sql IMMUTABLE STRICT
    """)

    # array_to_string is STABLE in core Postgres (locale-dependent). For a
    # simple ASCII space separator the result is deterministic, so a
    # thin IMMUTABLE wrapper is safe and lets us include alternate_names
    # in the generated column.
    execute("""
    CREATE OR REPLACE FUNCTION recco_immutable_array_to_string(text[], text)
    RETURNS text AS $$
      SELECT array_to_string($1, $2)
    $$ LANGUAGE sql IMMUTABLE
    """)

    execute("""
    ALTER TABLE board_games ADD COLUMN search_vector tsvector
      GENERATED ALWAYS AS (
        setweight(to_tsvector('simple'::regconfig, recco_immutable_unaccent(coalesce(name, ''))), 'A') ||
        setweight(
          to_tsvector(
            'simple'::regconfig,
            recco_immutable_unaccent(
              coalesce(recco_immutable_array_to_string(alternate_names, ' '), '')
            )
          ),
          'B'
        ) ||
        setweight(
          to_tsvector(
            'simple'::regconfig,
            recco_immutable_unaccent(coalesce(left(description, 10000), ''))
          ),
          'C'
        )
      ) STORED
    """)

    execute(
      "CREATE INDEX CONCURRENTLY board_games_search_vector_idx ON board_games USING gin (search_vector)"
    )
  end

  def down do
    execute("DROP INDEX CONCURRENTLY IF EXISTS board_games_search_vector_idx")
    execute("ALTER TABLE board_games DROP COLUMN IF EXISTS search_vector")
    execute("DROP FUNCTION IF EXISTS recco_immutable_array_to_string(text[], text)")
    execute("DROP FUNCTION IF EXISTS recco_immutable_unaccent(text)")
  end
end
