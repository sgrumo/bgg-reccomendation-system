# Production deploy

Run on the prod host, from the repo checkout:

```
git pull            # updated compose + configs
make prod-pull      # pull new app/recommender/db images
make prod-up        # recreate containers
```

Ecto migrations run automatically on app boot (`Recco.Release.migrate/0`, see the app
`Dockerfile` CMD). `depends_on: db (service_healthy)` guarantees the DB is up before the
app migrates.

## pgvector cutover (one-time)

The DB image is `pgvector/pgvector:pg18`. Two points when a host is still on
`postgres:18-alpine`:

- `make prod-up` recreates the DB container on the pgvector image before the app boots, so
  the `CREATE EXTENSION vector` migration finds the extension available. The `pgdata` volume
  persists — no data loss.
- The image moves from musl to glibc. Collation-sensitive indexes are best rebuilt once:

  ```
  docker compose -f infra/prod/docker-compose.yml --env-file infra/prod/.env \
    exec db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c 'REINDEX DATABASE "'"$POSTGRES_DB"'";'
  ```

## Semantic search rollout (one-time)

The `embedding` column and HNSW index migrations run automatically on app boot, but
the ~400k-row backfill does not — order matters:

1. Deploy. The `embedding` column is added (all NULL) and the HNSW index is created
   over those NULLs (instant, empty).
2. Run the backfill inside the recommender container — this is the long job:

   ```
   docker compose -f infra/prod/docker-compose.yml --env-file infra/prod/.env \
     exec recommender python -m scripts.backfill
   ```

   It is resumable (`WHERE embedding IS NULL`), so a crash or re-run continues where it
   stopped. The HNSW index fills in as rows are embedded.
3. From then on, freshness is automatic: the `board_games_clear_stale_embedding` trigger
   nulls an embedding when a game's text changes, new games start NULL, and the daily
   `Recco.Workers.RefreshEmbeddings` Oban job POSTs `/embeddings/refresh` so the
   recommender re-embeds whatever is pending.

### Search quality lever

If results are weak, swap `MODEL_NAME` in `recommender/src/embedding.py` to
`BAAI/bge-small-en-v1.5` (still fastembed, still 384-dim → no schema change) and re-run
the backfill after clearing embeddings:

```
docker compose ... exec db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -c 'UPDATE board_games SET embedding = NULL;'
docker compose ... exec recommender python -m scripts.backfill
```
