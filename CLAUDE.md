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

- `Recco.Accounts` — user registration, authentication, session tokens; soft-delete + restore + hard-delete with anonymization (see "Soft-delete" below); rate-limit-aware login
- `Recco.BoardGames` — board game CRUD, search/filter/pagination (FTS with tsvector + trigram fallback), crawl state, batch lookups by bgg_id, taxonomy sync (categories/mechanics lookup tables)
- `Recco.BoardGames.Cache` — Cachex façade for taxonomy / counters / canonical-default game list (see "Caching" below)
- `Recco.Ratings` — rate/delete games, user rating lists, per-user stats (count, avg, min, max), ratings-as-map for recommender
- `Recco.Preferences` — get/upsert user preferences (player count, weight, playtime ranges)
- `Recco.Recommender` — orchestrates calls to the FastAPI recommender, enriches results with local game data
- `Recco.RateLimit` + `Recco.Accounts.RateLimit` — Hammer-backed ETS buckets and auth-specific helpers (see "Rate limiting" below)
- `Recco.Observability` / `Recco.Observability.Counters` / `Recco.Observability.Alert` — telemetry handlers, rolling counters, email alert delivery (see "Observability" below)

### Error Flow

`Recco.Errors` defines typed error tuples (`{:error, reason}` or `{:error, reason, details}`). All context functions return `{:ok, result} | Errors.t()`. The `FallbackController` maps error atoms to HTTP status codes — controllers use `action_fallback` and return error tuples directly.

### Auth

Dual auth system:
- **API (JSON):** JWT Bearer token via `ReccoWeb.Plugs.Auth`. Swappable verifier: `Recco.Auth.Token` (prod) / `Recco.Auth.TokenMock` (test). Emits `[:recco, :auth, :token, :stop]` with `result: :ok | :missing | :invalid`.
- **Browser (LiveView):** Session-based auth using bcrypt password hashing. `ReccoWeb.Plugs.FetchCurrentUser` reads the session token and assigns `:current_user`. LiveView uses `ReccoWeb.Live.UserAuth` on_mount hooks. `Accounts.authenticate_user_by_email/2` emits `[:recco, :auth, :login, :stop]` (with `result` + hashed email) and wraps the bcrypt call in `[:recco, :auth, :bcrypt, :stop]` (so drift is observable).

`ReccoWeb.Plugs.FetchCurrentUser` and `UserToken.verify_session_token_query/1` both filter out soft-deleted users — tokens for a deleted account stop resolving without waiting for cookie expiry.

LiveView auth hooks:
- `:mount_current_user` — loads user if session exists, nil otherwise (used for public pages)
- `:ensure_authenticated` — redirects to `/login` if not logged in
- `:ensure_superadmin` — redirects to `/` if not a superadmin
- `:redirect_if_authenticated` — redirects to `/` if already logged in

Additional LiveView `on_mount` hooks (not auth-related but attached in every `live_session`):
- `ReccoWeb.Live.RequestIdHook` — generates a per-mount UUID and writes it to `Logger.metadata(:live_request_id)` so WebSocket-backed work can be correlated end-to-end (HTTP `Plug.RequestId` only covers the initial request)
- `ReccoWeb.Live.AdminPresenceHook` — chained AFTER `:ensure_superadmin` in the `:admin` live_session; tracks the current admin on the `"admin:presence"` topic and re-tracks the section on every `handle_params`

### Router Organization

Pipelines: `:api`, `:browser` (includes `put_secure_browser_headers` → `ReccoWeb.Plugs.SecurityHeaders` → `FetchCurrentUser`), `:authenticated` (JWT).

| Scope | Pipeline/Session | Description |
|---|---|---|
| `/health` | — | Health check (forwarded) |
| `/api` | `:api` | Public JSON endpoints (`/api/categories`, `/api/mechanics`, `POST /api/csp-report`) |
| `/api` | `:api` + `:authenticated` | Protected JSON endpoints |
| `/login`, `/register`, `/logout` | `:browser` | Session auth controllers (HTML). `POST /login` + `POST /register` carry `ReccoWeb.Plugs.RateLimit` |
| `/`, `/games`, `/games/:id` | `:public` live_session | Public LiveView (`:mount_current_user`) |
| `/ratings`, `/preferences`, `/recommendations` | `:authenticated` live_session | Authenticated LiveView (`:ensure_authenticated`) |
| `/admin/*` | `:admin` live_session | Admin LiveView (`:ensure_superadmin` + `AdminPresenceHook`) |
| `/admin/metrics` | `:browser` | TelemetryUI dashboard (plug-based) |

`ReccoWeb.Plugs.SecurityHeaders` runs on every browser response: emits CSP (enforcing or report-only per `:csp_mode`), `referrer-policy`, `permissions-policy`, and — in `:prod` over HTTPS only — HSTS. CSP violation reports land at `POST /api/csp-report` (logs a structured warning).

### Layouts

Three layout variants in `lib/recco_web/components/layouts/`:
- `public.html.heex` — minimal, for login/register pages
- `app.html.heex` — navbar with navigation, for public and authenticated pages
- `admin.html.heex` — sidebar navigation, for admin pages

### Web Module Dispatch

`ReccoWeb` defines `:controller` (JSON-only) and `:html_controller` (HTML+JSON) quoted blocks, plus `:live_view`, `:live_component`, `:html`. The `:html` block imports `CoreComponents` via `html_helpers`.

### OTP Supervision

Flat `one_for_one`:
Telemetry → Repo → [TelemetryUI] → Oban → DNSCluster → PubSub → `ReccoWeb.Presence` → Registry → DynamicSupervisor → Finch → `Recco.RateLimit` (Hammer ETS) → `Recco.Observability.Counters` → `Recco.BoardGames.Cache` child specs (3 Cachex instances) → Endpoint.

Registry + DynamicSupervisor are for per-session GenServer processes (primarily the BGG crawler). `Recco.Observability.attach_handlers/0` is called from `Application.start/2` BEFORE children start so telemetry handlers are live for the whole boot sequence.

### Navigation & JS Hooks

`ReccoWeb.Navigation` provides five components: `navbar/1` (sticky header with mobile toggle), `mobile_menu/1` (slide-in panel with focus trapping), `admin_sidebar/1` (fixed left sidebar for admin pages), `user_menu/1`, and `admin_presence_indicator/1` (compact list of other admins currently viewing `/admin/*` — rendered at the top of the admin layout).

Two JS hooks registered in `app.js`:
- `MobileMenu` — handles open/close animation, backdrop click, Escape key, tab focus trapping, body overflow
- `MultiSelect` — dropdown with search, checkboxes, click-outside-to-close; sends `phx-click` event with `{selected: [...]}` on change

### BGG Crawler

`Recco.BoardGames.Crawler` is a GenServer that crawls BGG XML API2 in batches of 20. Managed via `DynamicSupervisor`, controllable from `/admin/crawler`. Tracks progress in `crawl_state` table. Current BGG ID ceiling is ~468,680.

### Background Jobs (Oban)

`Recco.Workers.NewGameScanner` — weekly cron job (Monday 3 AM) that scans for new BGG entries beyond the current max `bgg_id`. Stops after 5 consecutive empty batches. Job status visible at `/admin/jobs`.

`Recco.Workers.SyncTaxonomy` — daily cron job (4 AM) that extracts distinct categories and mechanics from board_games JSONB columns into dedicated lookup tables (`categories`, `mechanics`). These tables power the multi-select filter dropdowns on the games page.

`Recco.Workers.DatabaseBackup` — weekly cron job (Sunday 2 AM) that runs `pg_dump --format=custom` to create compressed database dumps. Only active when `BACKUP_PATH` env var is set (prod only). Retains the last 4 backups and auto-prunes older ones. Restore with `pg_restore --dbname=<url> <file>`.

`Recco.Workers.AlertDispatcher` — runs every 5 minutes. Drains `Recco.Observability.Counters`, queries Oban for discarded-job signals, evaluates 4 rules, and delivers matching alerts via `Recco.Observability.Alert` (Swoosh email to `:alert_recipients`, falls back to `Logger.error` when recipients are unset). Per-rule dedup window is 30 min (ETS-based — resets on restart, which is acceptable for this cadence).

### Telemetry & Observability

`ReccoWeb.Telemetry` defines two metric sets: `metrics/0` (standard `Telemetry.Metrics` for reporters) and `ui_metrics/0` (`TelemetryUI.Metrics` for the dashboard). TelemetryUI uses its own metric types — do not pass `Telemetry.Metrics` structs to it. Avoid `queue_time` and `idle_time` DB metrics as they can be nil. Dashboard at `/admin/metrics`.

**App-emitted telemetry events:**

| Event | Metadata |
|---|---|
| `[:recco, :crawler, :batch, :stop]` | `status: :ok \| :rate_limited \| :queued \| :error`, `start_id`, `end_id`, `count` |
| `[:recco, :crawler, :batch, :exception]` | `start_id`, `end_id`, `kind`, `reason` |
| `[:recco, :bgg, :request, :stop]` | `endpoint: :thing \| :collection`, `status` (int or `:error`) |
| `[:recco, :auth, :login, :stop]` | `result: :ok \| :invalid_credentials \| :locked_out`, `email_hash` |
| `[:recco, :auth, :bcrypt, :stop]` | `path: :verify \| :no_user_verify` |
| `[:recco, :auth, :register, :stop]` | `result: :ok \| :invalid` |
| `[:recco, :auth, :token, :stop]` | `result: :ok \| :missing \| :invalid` |

`Recco.Observability.attach_handlers/0` is called at app start and installs logger-based handlers for crawler/Oban exceptions plus counter-incrementing handlers that feed `Recco.Observability.Counters` (ETS — keys: `:crawler_ok`, `:crawler_error`, `:bgg_429`, `:bgg_error`, `:auth_failed`, `:auth_locked_out`). The admin dashboard (`/admin`) shows live counter values in observability cards; the `AlertDispatcher` drains them every 5 minutes.

**Structured JSON logs in prod:** `config/runtime.exs` installs `LoggerJSON.Formatters.Basic` as the default handler formatter when `config_env() == :prod`. Dev/test keep the human-readable format. Logger metadata includes `request_id` (HTTP) and `live_request_id` (LiveView mount).

### Rate limiting

`Recco.RateLimit` wraps Hammer's ETS backend (`use Hammer, backend: :ets`). `Recco.Accounts.RateLimit` exposes three scopes:

| Scope | Default | Semantics |
|---|---|---|
| `:login_ip` | 5 attempts / 60 s per IP | Every attempt counted (via `hit/2`) |
| `:register_ip` | 5 attempts / 60 s per IP | Every attempt counted (via `hit/2`) |
| `:login_account` | 5 failures / 5 min per email | Only failures counted; success clears the bucket |

Limits live in `config :recco, Recco.Accounts.RateLimit, ...` and can be tuned per env. `ReccoWeb.Plugs.RateLimit` is applied in `UserSessionController` (`:create`) and `UserRegistrationController` (`:create`); it trusts `x-forwarded-for` first, falls back to `conn.remote_ip`. On deny: HTTP 429, `retry-after` header, re-rendered form with a localized message.

Per-account lockout is checked via `peek/2` (non-incrementing) BEFORE the bcrypt comparison, so a successful login never consumes a bucket slot. `clear/2` is called on successful auth. The account bucket is keyed by the normalized (trimmed + downcased) email — this means a failed attempt against a non-existent email still counts, which is the intentional behaviour (no user enumeration via rate-limit timing).

### Caching

`Recco.BoardGames.Cache` owns three Cachex instances (started from `child_specs/0` via `Recco.Application`):

| Cache | TTL | Keys |
|---|---|---|
| `:bgg_taxonomy_cache` | 24 h | `:categories`, `:mechanics` |
| `:bgg_counters_cache` | 60 s | `:board_game_count`, `:max_bgg_id` |
| `:bgg_popular_cache` | 10 min | `:default_page_1` (canonical `/games` landing only) |

`list_board_games/1` uses the popular cache ONLY when the opts map represents the canonical default (page 1, per_page 24, sort "rating", no search/filters). Filtered or paginated requests bypass the cache — avoids cardinality explosion.

`Cache.fetch/3` delegates to `Cachex.fetch/3` so cold-key computations are serialized (no thundering-herd). `Cache.invalidate/1` clears one cache; `Cache.invalidate_on_upsert/0` is a throttled (~5 s window, ETS-based) clear of counters+popular called from `upsert_board_game/1` so crawler batches don't churn the cache. `sync_taxonomy/0` clears the taxonomy cache at the end.

Disable via `config :recco, cache_enabled: false` — default in `:test` to avoid cross-test staleness. When disabled, `fetch/3` is a direct passthrough and `invalidate/*` are no-ops. Cache stats (hit rate per cache) are rendered in a card on the admin dashboard.

### Security headers

`ReccoWeb.Plugs.SecurityHeaders` is the last plug in the `:browser` pipeline. It emits:

- **Content-Security-Policy** (or `-Report-Only` based on `config :recco, :csp_mode`): `default-src 'self'`, `script-src 'self'` (no unsafe-inline — use nonces if inline scripts ever become necessary), `style-src 'self' 'unsafe-inline' https://fonts.googleapis.com` (inline required for LiveView transitions), `font-src 'self' https://fonts.gstatic.com`, `img-src 'self' data: https:` (BGG remote images), `connect-src 'self' ws: wss:` (+ `http: https:` in dev for LiveReload), `frame-ancestors 'none'`, `form-action 'self'`, `base-uri 'self'`, `object-src 'none'`, `report-uri /api/csp-report`
- `referrer-policy: strict-origin-when-cross-origin`
- `permissions-policy: camera=(), microphone=(), geolocation=(), interest-cohort=()`
- `strict-transport-security: max-age=31536000; includeSubDomains` — ONLY in `:prod` over HTTPS

Prod defaults to Report-Only via `runtime.exs`; flip to enforcement with `CSP_MODE=enforce`. `ReccoWeb.CspReportController` handles both `application/reports+json` (Reporting API; parsed by `Plug.Parsers.JSON` via the `+json` suffix) and legacy `application/csp-report` (body read manually because Plug's JSON parser doesn't match that content type).

### Soft-delete

`Accounts.delete_user/1` is an alias for `soft_delete_user/1` — the default path. Soft-delete:
1. Sets `deleted_at = now()`
2. Anonymizes: `email → deleted-<uuid>@invalid.local`, `username → deleted_<hex>`, `hashed_password → unverifiable hash`, `bgg_username → nil`
3. `Multi.delete_all` on `user_tokens`, `user_preferences`, `user_wishlists`
4. **Keeps** `user_ratings` and `recommendation_feedback` (statistical value for the recommender — documented tradeoff)

`Accounts.restore_user/1` clears `deleted_at` within a 30-day window (PII is gone; only the account row + ratings come back). `Accounts.hard_delete_user/1` does a full `Repo.delete` (FK cascades clean up everything). Both refuse superadmins.

**All read paths are scoped to active users:** `get_user_by_email/1`, `get_user_by_id/1`, `authenticate_user_by_email/2`, `list_users/1` (default), and `UserToken.verify_*_query/1`. `Accounts.admin_get_user_by_id/1` bypasses the active scope for admin tombstone rendering/restore. `list_users/1` accepts `include_deleted: true` to surface tombstones in the admin index.

Admin UI (`ReccoWeb.Admin.UserLive.Show`) shows three buttons for base users: Soft delete, Restore (when `deleted_at` is set), Hard delete. The index lists tombstones behind a "Show deleted" toggle (query param `?deleted=1`).

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

- `users` — email (citext, unique), username (unique), hashed_password, role (base/superadmin), `deleted_at :utc_datetime` (soft-delete tombstone marker)
- `user_tokens` — session tokens (binary token, hashed, context, expires after 60 days)
- `user_ratings` — user_id + board_game_id (unique pair), score 1.0-10.0, optional comment
- `user_preferences` — user_id (unique), preferred categories/mechanics (jsonb arrays), player count/weight/playtime ranges
- `user_wishlists`, `recommendation_feedback` — standard per-user tables

### Search Indexes

- `pg_trgm` GIN index on `board_games.name` for trigram similarity (typo fallback)
- `jsonb_path_ops` GIN indexes on `board_games.categories` and `board_games.mechanics` for JSONB containment queries
- **`board_games.search_vector`** — generated `tsvector` column, weighted `A` (name) + `B` (alternate_names) + `C` (description, first 10k chars). GIN index `board_games_search_vector_idx` (built `CONCURRENTLY`). Uses `'simple'::regconfig` + `recco_immutable_unaccent` for accent-insensitive, multilingual-friendly tokenization with no English stemming. When a search term is present, results are ordered by `ts_rank_cd(search_vector, tsquery, 32) DESC, similarity(name, term) DESC, bayes_average_rating DESC NULLS LAST` — so name hits (weight A) dominate description hits (weight C) regardless of bayes rating
- `users_active_idx` — partial index on `users(id) WHERE deleted_at IS NULL`

### SQL Helper Functions (created by migrations)

- `recco_immutable_unaccent(text) RETURNS text` — IMMUTABLE wrapper over `unaccent('unaccent', $1)` so it can appear in the generated column expression
- `recco_immutable_array_to_string(text[], text) RETURNS text` — IMMUTABLE wrapper over `array_to_string/2` (core version is STABLE; safe to treat as immutable for ASCII joining)

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
- Weekly database backups via Oban (`BACKUP_PATH` env var, prod only). Named volume `backups` in docker-compose. App container includes `postgresql-client` for `pg_dump`

### Environment variables (runtime)

| Variable | Scope | Purpose |
|---|---|---|
| `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT` | prod | Standard Phoenix runtime |
| `RECOMMENDER_URL` | all | FastAPI recommender endpoint |
| `BGG_BEARER_TOKEN` | all | Optional BGG API auth |
| `BACKUP_PATH` | prod | Enables weekly DB backup worker |
| `ALERT_RECIPIENTS` | prod | Comma-separated emails receiving observability alerts; falls back to `Logger.error` when unset |
| `CSP_MODE` | prod | `enforce` flips CSP out of Report-Only (default) |
| `MAILER_ADAPTER`, `MAILER_API_KEY` | prod | Swoosh adapter selection (resend \| brevo) |

### Test config notes

- `config :recco, cache_enabled: false` — caches are passthrough in tests
- `config :recco, Recco.Accounts.RateLimit, login_ip_limit: 100, ...` — high baseline so incidental tests don't trip limits; the few rate-limit-focused tests are `async: false` and override via `Application.put_env/3`
- `config :recco, csp_mode: :enforce` — dev/test enforce immediately
