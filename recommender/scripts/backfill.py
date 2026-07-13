"""One-time (and resumable) CLI backfill of board_games.embedding.

Run from the recommender/ directory:

    python -m scripts.backfill
"""

import sys

from src.backfill import backfill_embeddings, count_pending
from src.db import connect


def main() -> int:
    engine = connect()

    remaining = count_pending(engine)
    print(f"rows to embed: {remaining}", flush=True)

    done = backfill_embeddings(
        engine, on_progress=lambda n: print(f"embedded {n}/{remaining}", flush=True)
    )

    print(f"done. embedded {done} rows this run.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
