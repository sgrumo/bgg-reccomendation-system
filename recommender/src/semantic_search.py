"""Semantic search over board_games via pgvector cosine distance.

Independent of the in-memory RecommendationEngine: it queries the DB directly,
so it covers every embedded row regardless of rating count.
"""

from sqlalchemy import text
from sqlalchemy.engine import Engine

from src.embedding import embed_texts, to_pgvector


def semantic_search(
    db_engine: Engine, query: str, limit: int = 20
) -> list[dict[str, float | int | str]]:
    """Return games whose embedding is nearest to the query, best first.

    ``score`` is cosine similarity in [0, 1] (``1 - cosine_distance``).
    """
    qvec = to_pgvector(embed_texts([query])[0])
    with db_engine.connect() as conn:
        rows = (
            conn.execute(
                text(
                    """
                    SELECT
                        bgg_id,
                        name,
                        1 - (embedding <=> CAST(:qvec AS vector)) AS score
                    FROM board_games
                    WHERE embedding IS NOT NULL
                    ORDER BY embedding <=> CAST(:qvec AS vector)
                    LIMIT :limit
                    """
                ),
                {"qvec": qvec, "limit": limit},
            )
            .mappings()
            .all()
        )

    return [
        {"bgg_id": int(r["bgg_id"]), "name": str(r["name"]), "score": float(r["score"])}
        for r in rows
    ]
