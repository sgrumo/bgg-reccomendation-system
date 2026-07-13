"""Reusable embedding backfill, shared by the CLI script and the API endpoint.

Embeds every board_games row whose embedding is NULL, in batches. Idempotent
and resumable: ``WHERE embedding IS NULL`` means a crash — or a second concurrent
run — simply continues over whatever remains.
"""

from typing import Callable

from sqlalchemy import text
from sqlalchemy.engine import Connection, Engine

from src.embedding import build_embedding_text, embed_texts, to_pgvector

BATCH_SIZE = 500


def count_pending(db_engine: Engine) -> int:
    """Number of rows still awaiting an embedding."""
    with db_engine.connect() as conn:
        return conn.execute(
            text("SELECT COUNT(*) FROM board_games WHERE embedding IS NULL")
        ).scalar_one()


def _fetch_batch(conn: Connection, batch_size: int) -> list:
    return (
        conn.execute(
            text(
                """
                SELECT id, name, description, categories, mechanics
                FROM board_games
                WHERE embedding IS NULL
                ORDER BY id
                LIMIT :limit
                """
            ),
            {"limit": batch_size},
        )
        .mappings()
        .all()
    )


def backfill_embeddings(
    db_engine: Engine,
    batch_size: int = BATCH_SIZE,
    on_progress: Callable[[int], None] | None = None,
) -> int:
    """Embed all rows with a NULL embedding. Returns the number embedded."""
    done = 0
    while True:
        with db_engine.connect() as conn:
            rows = _fetch_batch(conn, batch_size)
        if not rows:
            break

        texts = [
            build_embedding_text(
                r["name"], r["description"], r["categories"], r["mechanics"]
            )
            for r in rows
        ]
        params = [
            {"emb": to_pgvector(vec), "id": r["id"]}
            for r, vec in zip(rows, embed_texts(texts))
        ]
        with db_engine.begin() as conn:
            conn.execute(
                text("UPDATE board_games SET embedding = CAST(:emb AS vector) WHERE id = :id"),
                params,
            )

        done += len(rows)
        if on_progress:
            on_progress(done)

    return done
