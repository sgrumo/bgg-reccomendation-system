# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Recco is a board game recommendation system with a full LiveView web platform. The backend is a Phoenix 1.8 application (JSON API + LiveView) backed by PostgreSQL with Ecto. It crawls board game data from BoardGameGeek's XML API. The recommendation engine is a separate Python project under `recommender/` using scikit-learn for content-based similarity, exposed via a FastAPI service.

The LiveView platform has two user roles: **superadmin** (admin dashboards, user management, crawler control, job monitoring) and **base users** (browse games, rate, get recommendations). Public browsing is allowed without login. The UI uses a **neobrutalist** design style (bold borders, offset shadows, high contrast colors) with light/dark theme support via CSS custom properties.

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
- `make dev-recommender` — start FastAPI recommender on port 8000

## Architecture

### Context Pattern

Strict separation: `lib/recco/` (business logic) vs `lib/recco_web/` (web layer). Controllers never touch `Repo` directly — all DB access goes through context modules.

### Contexts

- `Recco.Accounts` — user registration, authentication, session tokens, user listing/deletion (admin)
- `Recco.BoardGames` — board game CRUD, search/filter/pagination, crawl state, batch lookups by bgg_id, taxonomy sync (categories/mechanics lookup tables)
- `Recco.Ratings` — rate/delete games, user rating lists, per-user stats (count, avg, min, max), ratings-as-map for recommender
- `Recco.Preferences` — get/upsert user preferences (player count, weight, playtime ranges)
- `Recco.Recommender` — orchestrates calls to the FastAPI recommender, enriches results with local game data

### Error Flow

`Recco.Errors` defines typed error tuples (`{:error, reason}` or `{:error, reason, details}`). All context functions return `{:ok, result} | Errors.t()`. The `FallbackController` maps error atoms to HTTP status codes — controllers use `action_fallback` and return error tuples directly.

### Auth

Dual auth system:
- **API (JSON):** JWT Bearer token via `ReccoWeb.Plugs.Auth`. Swappable verifier: `Recco.Auth.Token` (prod) / `Recco.Auth.TokenMock` (test).
- **Browser (LiveView):** Session-based auth using bcrypt password hashing. `ReccoWeb.Plugs.FetchCurrentUser` reads the session token and assigns `:current_user`. LiveView uses `ReccoWeb.Live.UserAuth` on_mount hooks.

LiveView auth hooks:
- `:mount_current_user` — loads user if session exists, nil otherwise (used for public pages)
- `:ensure_authenticated` — redirects to `/login` if not logged in
- `:ensure_superadmin` — redirects to `/` if not a superadmin
- `:redirect_if_authenticated` — redirects to `/` if already logged in

### Router Organization

Pipelines: `:api`, `:browser` (includes `FetchCurrentUser`), `:authenticated` (JWT).

| Scope | Pipeline/Session | Description |
|---|---|---|
| `/health` | — | Health check (forwarded) |
| `/api` | `:api` | Public JSON endpoints (`/api/categories`, `/api/mechanics`) |
| `/api` | `:api` + `:authenticated` | Protected JSON endpoints |
| `/login`, `/register`, `/logout` | `:browser` | Session auth controllers (HTML) |
| `/`, `/games`, `/games/:id` | `:public` live_session | Public LiveView (`:mount_current_user`) |
| `/ratings`, `/preferences`, `/recommendations` | `:authenticated` live_session | Authenticated LiveView (`:ensure_authenticated`) |
| `/admin/*` | `:admin` live_session | Admin LiveView (`:ensure_superadmin`) |
| `/admin/metrics` | `:browser` | TelemetryUI dashboard (plug-based) |

### Layouts

Three layout variants in `lib/recco_web/components/layouts/`:
- `public.html.heex` — minimal, for login/register pages
- `app.html.heex` — navbar with navigation, for public and authenticated pages
- `admin.html.heex` — sidebar navigation, for admin pages

### Web Module Dispatch

`ReccoWeb` defines `:controller` (JSON-only) and `:html_controller` (HTML+JSON) quoted blocks, plus `:live_view`, `:live_component`, `:html`. The `:html` block imports `CoreComponents` via `html_helpers`.

### OTP Supervision

Flat `one_for_one`: Telemetry -> Repo -> [TelemetryUI] -> Oban -> DNSCluster -> PubSub -> Registry -> DynamicSupervisor -> Endpoint. Registry + DynamicSupervisor for per-session GenServer processes.

### Navigation & JS Hooks

`ReccoWeb.Navigation` provides four components: `navbar/1` (sticky header with mobile toggle), `mobile_menu/1` (slide-in panel with focus trapping), `admin_sidebar/1` (fixed left sidebar for admin pages), and `user_menu/1`.

Two JS hooks registered in `app.js`:
- `MobileMenu` — handles open/close animation, backdrop click, Escape key, tab focus trapping, body overflow
- `MultiSelect` — dropdown with search, checkboxes, click-outside-to-close; sends `phx-click` event with `{selected: [...]}` on change

### BGG Crawler

`Recco.BoardGames.Crawler` is a GenServer that crawls BGG XML API2 in batches of 20. Managed via `DynamicSupervisor`, controllable from `/admin/crawler`. Tracks progress in `crawl_state` table. Current BGG ID ceiling is ~468,680.

### Background Jobs (Oban)

`Recco.Workers.NewGameScanner` — weekly cron job (Monday 3 AM) that scans for new BGG entries beyond the current max `bgg_id`. Stops after 5 consecutive empty batches. Job status visible at `/admin/jobs`.

`Recco.Workers.SyncTaxonomy` — daily cron job (4 AM) that extracts distinct categories and mechanics from board_games JSONB columns into dedicated lookup tables (`categories`, `mechanics`). These tables power the multi-select filter dropdowns on the games page.

### Telemetry

`ReccoWeb.Telemetry` defines two metric sets: `metrics/0` (standard `Telemetry.Metrics` for reporters) and `ui_metrics/0` (`TelemetryUI.Metrics` for the dashboard). TelemetryUI uses its own metric types — do not pass `Telemetry.Metrics` structs to it. Avoid `queue_time` and `idle_time` DB metrics as they can be nil. Dashboard at `/admin/metrics`.

### Recommender Integration

The Phoenix app calls the FastAPI recommender via `Recco.Recommender`, which delegates to a swappable client:
- `Recco.Recommender.HttpClient` (prod) — makes HTTP calls via Req
- `Recco.Recommender.Mock` (test) — returns canned data

Config: `recommender_url` (default `http://localhost:8000`), `recommender_client` (swappable).

Endpoints called:
- `GET /games/{bgg_id}/recommendations?top_n=N` — game-to-game similarity
- `POST /users/recommendations?top_n=N` — user profile recommendations (body: `{ratings: {bgg_id: score}}`)

## Recommendation Engine (Python)

Located in `recommender/`. Uses scikit-learn for content-based recommendation via cosine similarity.

### Structure

- `api.py` — FastAPI app wrapping the engine (`uvicorn api:app --port 8000`)
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

## Database Schema

### Core Tables

- `board_games` — crawled BGG data (bgg_id unique, JSONB for categories/mechanics/families/etc, GIN indexes for search)
- `crawl_state` — crawler progress tracking (key, last_fetched_id, status)
- `categories` — taxonomy lookup (bgg_id unique, name unique), synced from board_games JSONB
- `mechanics` — taxonomy lookup (bgg_id unique, name unique), synced from board_games JSONB

### User Tables

- `users` — email (citext, unique), username (unique), hashed_password, role (base/superadmin)
- `user_tokens` — session tokens (binary token, hashed, context, expires after 60 days)
- `user_ratings` — user_id + board_game_id (unique pair), score 1.0-10.0, optional comment
- `user_preferences` — user_id (unique), preferred categories/mechanics (jsonb arrays), player count/weight/playtime ranges

### Search Indexes

- `pg_trgm` GIN index on `board_games.name` for fuzzy text search
- `jsonb_path_ops` GIN indexes on `board_games.categories` and `board_games.mechanics` for JSONB containment queries

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
- `log_in_user(conn, user)` helper available in ConnCase for session-based browser/LiveView tests
- Python code must use type hints on all functions
- LiveView `start_async` — extract assigns to local variables before the closure to avoid copying the whole socket

## Testing Principles

- Test observable behavior, not implementation details
- Avoid overlapping tests and subtle duplication
- Ensure every test actually runs (no dead conditional paths)
- Keep tests simple and fast
- LiveView tests use `Phoenix.LiveViewTest` (requires `lazy_html` dep)

## Infrastructure

- Docker Postgres on port **5460** (not default 5432, to avoid conflicts)
- Named volume `pgdata` for data persistence
- `mix ecto.reset` will destroy all crawled data — avoid unless intentional
- FastAPI recommender runs on port **8000** (configurable via `RECOMMENDER_URL` env var)
- bcrypt log_rounds set to 1 in test config for fast password hashing
