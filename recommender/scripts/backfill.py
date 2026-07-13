"""Backfill board_games.embedding for semantic search.

Streams rows that lack an embedding, builds the shared embedding text, embeds in
batches, and writes the vectors back. Re-running is safe: ``WHERE embedding IS
NULL`` means a crash resumes from where it stopped rather than restarting.

Run from the recommender/ directory:

    python -m scripts.backfill
"""

import sys

from sqlalchemy import text
from sqlalchemy.engine import Connection

from src.db import connect
from src.embedding import build_embedding_text, embed_texts, to_pgvector

BATCH_SIZE = 500


def _fetch_batch(conn: Connection) -> list:
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
            {"limit": BATCH_SIZE},
        )
        .mappings()
        .all()
    )


def main() -> int:
    engine = connect()

    with engine.connect() as conn:
        remaining = conn.execute(
            text("SELECT COUNT(*) FROM board_games WHERE embedding IS NULL")
        ).scalar_one()
    print(f"rows to embed: {remaining}", flush=True)

    done = 0
    while True:
        with engine.connect() as conn:
            rows = _fetch_batch(conn)
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
        with engine.begin() as conn:
            conn.execute(
                text("UPDATE board_games SET embedding = CAST(:emb AS vector) WHERE id = :id"),
                params,
            )

        done += len(rows)
        print(f"embedded {done}/{remaining}", flush=True)

    print(f"done. embedded {done} rows this run.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
