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
