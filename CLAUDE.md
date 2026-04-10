# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Recco is a board game recommendation system. The backend is a Phoenix 1.8 application (JSON API + LiveView) backed by PostgreSQL with Ecto. It crawls board game data from BoardGameGeek's XML API. The recommendation engine is a separate Python project under `recommender/` using scikit-learn for content-based similarity.

## Common Commands

- `mix setup` — install deps, create DB, run migrations, seed, install assets
- `mix phx.server` — start the server (localhost:4000)
- `iex -S mix phx.server` — start with interactive shell
- `mix test` — run all tests (auto-creates/migrates DB)
- `mix test test/path/to/test.exs` — run a single test file
- `mix test test/path/to/test.exs:42` — run a specific test by line number
- `mix test --failed` — re-run previously failed tests
- `mix precommit` — compile (warnings-as-errors), unlock unused deps, format, test. **Run before committing.**
- `mix ecto.gen.migration migration_name` — generate a new migration (always use this, never create manually)
- `mix ecto.migrate` / `mix ecto.reset` — run migrations / drop + recreate
- `mix credo --strict` — static analysis
- `mix dialyzer` — type checking (first run builds PLT, takes a while)
- `make up` / `make down` — start/stop Docker Postgres (port 5460)
- `make dev-api` — start infra + setup + dev server

## Architecture

### Context Pattern

Strict separation: `lib/recco/` (business logic) vs `lib/recco_web/` (web layer). Controllers never touch `Repo` directly — all DB access goes through context modules.

### Error Flow

`Recco.Errors` defines typed error tuples (`{:error, reason}` or `{:error, reason, details}`). All context functions return `{:ok, result} | Errors.t()`. The `FallbackController` maps error atoms to HTTP status codes — controllers use `action_fallback` and return error tuples directly.

### Auth

Swappable token verification via config: `config :recco, token_verifier: Recco.Auth.Token` (production) / `Recco.Auth.TokenMock` (test). The `ReccoWeb.Plugs.Auth` plug reads config at runtime. LiveView auth uses session-based `on_mount` hook (`ReccoWeb.Live.AuthHook`).

### Router Organization

Pipelines: `:api`, `:browser`, `:authenticated`. Health check forwarded to `ReccoWeb.Health.Router`. Scopes: public API, authenticated API, admin (browser + LiveView with auth hook). Dev routes (behind `dev_routes` config flag): `/dev/crawler` (crawler LiveView dashboard), `/dev/metrics` (TelemetryUI dashboard).

### Web Module Dispatch

`ReccoWeb` defines `:controller` (JSON-only) and `:html_controller` (HTML+JSON) quoted blocks, plus `:live_view`, `:live_component`, `:html`.

### OTP Supervision

Flat `one_for_one`: Telemetry -> Repo -> [TelemetryUI] -> Oban -> DNSCluster -> PubSub -> Registry -> DynamicSupervisor -> Endpoint. Registry + DynamicSupervisor for per-session GenServer processes.

### BGG Crawler

`Recco.BoardGames.Crawler` is a GenServer that crawls BGG XML API2 in batches of 20. Managed via `DynamicSupervisor`, controllable from the `/dev/crawler` LiveView. Tracks progress in `crawl_state` table. Current BGG ID ceiling is ~468,680.

### Background Jobs (Oban)

`Recco.Workers.NewGameScanner` — weekly cron job (Monday 3 AM) that scans for new BGG entries beyond the current max `bgg_id`. Stops after 5 consecutive empty batches.

### Telemetry

`ReccoWeb.Telemetry` defines two metric sets: `metrics/0` (standard `Telemetry.Metrics` for reporters) and `ui_metrics/0` (`TelemetryUI.Metrics` for the dashboard). TelemetryUI uses its own metric types — do not pass `Telemetry.Metrics` structs to it. Avoid `queue_time` and `idle_time` DB metrics as they can be nil.

## Recommendation Engine (Python)

Located in `recommender/`. Uses scikit-learn for content-based recommendation via cosine similarity.

### Structure

- `src/db.py` — SQLAlchemy connection to Postgres (port 5460), loads board games
- `src/preprocess.py` — cleaning pipeline: outlier capping, fill missing, min rating filter, derived features
- `src/features.py` — builds feature matrix: MinMax scaled numerics + one-hot encoded categories/mechanics/families
- `src/similarity.py` — cosine similarity with edition filtering via BGG "Game: X" family tags
- `src/engine.py` — `RecommendationEngine` class: loads data, builds features, serves recommendations per-game and per-user-profile
- `src/visualize.py` — matplotlib plots for data exploration
- `explore.ipynb` — Jupyter notebook for interactive exploration
- `main.py` — CLI test script

### Key Details

- BGG JSON fields use `"value"` key (not `"name"`) for labels in categories/mechanics/families
- Edition filtering: games sharing a `"Game: X"` family tag are considered the same game
- User profile recommendations: weighted average of feature vectors using user ratings as weights, then cosine similarity against all games
- Preprocessing filters to games with >= 30 ratings

## Key Conventions

- Generators use `binary_id: true` and `utc_datetime` timestamps
- Use `Req` for HTTP requests (avoid HTTPoison, Tesla, httpc)
- Never nest multiple modules in the same file
- Ecto schema `:text` columns use `:string` type
- Fields set programmatically (e.g. `user_id`) must not appear in `cast` — set them explicitly
- Use `Ecto.Changeset.get_field/2` to read changeset fields (not `changeset[:field]`)
- Phoenix router `scope` blocks auto-prefix module aliases — don't duplicate them
- Use `start_supervised!/1` in tests; avoid `Process.sleep/1`
- Predicate functions end with `?` (no `is_` prefix unless it's a guard)
- Don't use `String.to_atom/1` on user input
- Every public function must have `@spec` (Credo strict mode enforces this)
- No vague module names: Manager, Helper, Utils, Fetcher, Builder, Serializer
- JSON API responses wrapped: `%{data: ...}`
- Test factories via ExMachina (`test/support/factory.ex`), auto-imported in ConnCase/DataCase
- `authenticate(conn)` helper available in ConnCase for authenticated API tests
- Python code must use type hints on all functions

## Testing Principles

- Test observable behavior, not implementation details
- Avoid overlapping tests and subtle duplication
- Ensure every test actually runs (no dead conditional paths)
- Keep tests simple and fast

## Infrastructure

- Docker Postgres on port **5460** (not default 5432, to avoid conflicts)
- Named volume `pgdata` for data persistence
- `mix ecto.reset` will destroy all crawled data — avoid unless intentional
