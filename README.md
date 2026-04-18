# Recco

Board game recommendation system powered by data crawled from [BoardGameGeek](https://boardgamegeek.com/). Phoenix 1.8 LiveView platform with a Python-based content-based recommendation engine.

## Features

- **Browse & Search** — ~468K board games with Postgres `tsvector` full-text search (weighted name/alternate_names/description, accent-insensitive), trigram typo fallback, category/mechanic filters, sorting, pagination
- **User Accounts** — session-based auth with registration, login, role-based access (base user / superadmin). Rate-limited login/registration, per-account lockout on repeated failures
- **Soft-delete** — admin can soft-delete users (anonymize + keep ratings for stats), restore within 30 days, or hard-delete
- **Ratings** — rate games 1-10 from the game detail page, manage ratings from "My Ratings"
- **Recommendations** — personalised "For You" page powered by your ratings, plus "Similar Games" on each game detail page
- **Preferences** — set preferred player count, weight, and playtime ranges
- **Admin Dashboard** — user management, background job monitoring, crawler control, cache hit rates, live observability counters, presence (see which admins are online and on which section), telemetry charts at `/admin/metrics`
- **Operational Hardening** — CSP + HSTS + Referrer-Policy + Permissions-Policy, structured JSON logs in prod, Oban-driven alert dispatcher (email via Swoosh), Cachex-backed hot-read cache
- **Neobrutalist Design** — bold borders, offset shadows, high contrast colors with light/dark theme
- **Mobile-first** — responsive layouts, hamburger menu with focus trapping, accessible navigation

## Stack

### Backend (Elixir/Phoenix)
- **Elixir** ~> 1.19, **Phoenix** ~> 1.8, **Phoenix LiveView** ~> 1.0
- **Ecto** with PostgreSQL (binary UUIDs, UTC datetime timestamps)
- **Bandit** as HTTP server
- **Oban** for background job scheduling
- **bcrypt_elixir** for password hashing
- **Hammer** (ETS backend) for rate limiting
- **Cachex** for hot-read caching
- **esbuild** + **Tailwind CSS** for asset bundling (no Node.js)
- **Joken** for JWT verification (API), **Corsica** for CORS
- **Swoosh** for transactional + alert emails
- **logger_json** for structured logs in prod

### Recommendation Engine (Python)
- **FastAPI** + **uvicorn** for the HTTP API
- **pandas** + **scikit-learn** for feature engineering and similarity
- **SQLAlchemy** + **psycopg2** for database access

## Getting Started

### Prerequisites

- Elixir ~> 1.19
- Python >= 3.12
- PostgreSQL (or Docker)

### Setup

Start the database (port 5460):

```bash
make up
```

Install dependencies, create the database, run migrations, and install assets:

```bash
mix setup
```

Start the Phoenix server:

```bash
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000).

### Recommendation Engine

```bash
cd recommender
python -m venv .venv
source .venv/bin/activate
pip install -e .
```

Start the FastAPI service:

```bash
make dev-recommender
# or: cd recommender && uvicorn api:app --host 0.0.0.0 --port 8000 --reload
```

The Phoenix app connects to the recommender at `http://localhost:8000` by default (configurable via `RECOMMENDER_URL` env var).

### Create a Superadmin

```elixir
iex -S mix phx.server

{:ok, user} = Recco.Accounts.register_user(%{
  email: "admin@example.com",
  username: "admin",
  password: "admin_password123"
})

user
|> Recco.Accounts.User.role_changeset(%{role: "superadmin"})
|> Recco.Repo.update()
```

Then log in at `/login` and visit `/admin`.

## Routes

### Public (no login required)

| Route | Description |
|---|---|
| `/` | Landing page |
| `/games` | Browse, search, filter, sort board games |
| `/games/:id` | Game detail (stats, description, similar games) |
| `/login` | Sign in |
| `/register` | Create account |

### Authenticated (login required)

| Route | Description |
|---|---|
| `/ratings` | Your rated games |
| `/preferences` | Set recommendation preferences |
| `/recommendations` | Personalised game recommendations |

### Admin (superadmin only)

| Route | Description |
|---|---|
| `/admin` | Dashboard: stat cards + crawler status + Oban health + auth/BGG counters + per-cache hit rates. Live presence indicator shows which other admins are online and on which section |
| `/admin/users` | User list with search, rating counts. `?deleted=1` toggles tombstone visibility |
| `/admin/users/:id` | User detail with stats, ratings, and **Soft delete / Restore / Hard delete** actions |
| `/admin/jobs` | Oban background job monitoring |
| `/admin/crawler` | BGG crawler control (start/stop, progress) |
| `/admin/metrics` | TelemetryUI metrics dashboard (Phoenix, DB, VM, Crawler, BGG API, Auth, Oban) |

### API

| Route | Pipeline | Description |
|---|---|---|
| `/health` | — | Health check |
| `/api/categories` | `:api` | List all game categories |
| `/api/mechanics` | `:api` | List all game mechanics |
| `POST /api/csp-report` | `:api` | Receives CSP violation reports (logs structured warning) |
| `/api/*` | `:authenticated` | Protected JSON endpoints (JWT Bearer) |

## Project Structure

```
lib/
  recco/                         # Core business logic (contexts)
    accounts.ex                      # Register, auth (rate-limit-aware), soft/hard delete, restore
    accounts/
      user.ex                        # User schema (+ deleted_at)
      user_token.ex                  # Session token schema (60-day expiry, scoped to active users)
      user_rating.ex                 # Rating schema (user + game, score 1-10)
      user_preference.ex             # Preference schema (categories, mechanics, ranges)
      user_wishlist.ex               # Wishlist schema
      rate_limit.ex                  # Auth-specific Hammer helpers (login_ip / register_ip / login_account)
    board_games.ex                   # Games: FTS search, filter/paginate, batch lookups, cache-aware reads
    board_games/
      board_game.ex                  # BoardGame schema (BGG data, JSONB fields)
      bgg_api.ex                     # BGG XML API client (telemetry-instrumented)
      crawler.ex                     # GenServer-based BGG crawler (telemetry-instrumented)
      crawl_state.ex                 # Crawler progress tracking
      category.ex                    # Category lookup schema
      mechanic.ex                    # Mechanic lookup schema
      cache.ex                       # Cachex façade: taxonomy / counters / popular
    rate_limit.ex                    # Top-level Hammer module (ETS backend)
    observability.ex                 # Telemetry handlers + counter bumps
    observability/
      counters.ex                    # ETS rolling counters for alert rules
      alert.ex                       # Email delivery via Swoosh
    ratings.ex                       # Ratings: rate/delete, user stats, ratings map
    preferences.ex                   # Preferences: get/upsert
    recommender.ex                   # Recommender: orchestrates FastAPI calls
    recommender/
      http_client.ex                 # Req-based HTTP client for FastAPI
      mock.ex                        # Test mock
    errors.ex                        # Shared typed error tuples
    auth/
      token.ex                       # JWT verification (Joken)
      token_mock.ex                  # Test mock
    workers/
      new_game_scanner.ex            # Oban: weekly scan for new BGG entries
      sync_taxonomy.ex               # Oban: daily sync categories/mechanics lookup tables
      database_backup.ex             # Oban: weekly pg_dump (BACKUP_PATH only)
      alert_dispatcher.ex            # Oban: 5-min alert evaluator
  recco_web/                     # Web layer
    endpoint.ex                      # HTTP endpoint (sessions, CORS, static)
    router.ex                        # Routes (public, auth, admin, API)
    telemetry.ex                     # Telemetry metrics (Phoenix + DB + VM + Crawler + BGG + Auth + Oban)
    presence.ex                      # Phoenix.Presence for admin:presence topic
    components/
      core_components.ex             # Shared UI: input, flash, icon
      navigation.ex                  # Navbar, mobile menu, admin sidebar, admin_presence_indicator, user_menu
      layouts.ex                     # Layout module (embeds templates)
      layouts/
        root.html.heex               # HTML shell (skip-to-content, assets)
        app.html.heex                # Main layout (navbar + content)
        public.html.heex             # Minimal layout (login/register)
        admin.html.heex              # Admin layout (sidebar + presence + content)
    controllers/
      user_session_controller.ex     # Login (rate-limited) + logout
      user_registration_controller.ex # Registration (rate-limited)
      taxonomy_controller.ex         # GET /api/categories, /api/mechanics
      csp_report_controller.ex       # POST /api/csp-report (CSP violations)
      fallback_controller.ex         # Error tuple → HTTP response
    plugs/
      auth.ex                        # JWT Bearer token verification (API) + telemetry
      fetch_current_user.ex          # Session → :current_user assign (browser)
      rate_limit.ex                  # Per-IP rate limiting for login/register
      security_headers.ex            # CSP (+ Report-Only) + HSTS + Referrer-Policy + Permissions-Policy
    live/
      user_auth.ex                   # LiveView on_mount hooks (4 variants)
      request_id_hook.ex             # on_mount: per-mount UUID → Logger metadata
      admin_presence_hook.ex         # on_mount: track superadmin on admin:presence topic
      landing_live.ex                # Landing page (/)
      game_live/
        index.ex                     # Browse games (/games)
        show.ex                      # Game detail (/games/:id) + rating widget + similar games
      rating_live/
        index.ex                     # My Ratings (/ratings)
      preference_live/
        edit.ex                      # Preferences form (/preferences)
      recommendation_live/
        index.ex                     # For You page (/recommendations)
      admin/
        dashboard_live.ex            # Admin dashboard with observability + cache cards (/admin)
        user_live/
          index.ex                   # User management with "Show deleted" toggle
          show.ex                    # User detail + soft/restore/hard delete
        job_live.ex                  # Oban job monitoring (/admin/jobs)
        crawler_live.ex              # Crawler control (/admin/crawler)
    health/
      router.ex                      # GET /health
      checks.ex                      # Health check implementations
assets/
  js/
    app.js                           # LiveSocket setup, hook registration
    hooks/
      mobile_menu.js                 # Focus trapping, escape-to-close, slide animation
      multi_select.js                # Dropdown with search, checkboxes, phx-click events
  css/
    app.css                          # Tailwind imports
  tailwind.config.js                 # Brand colors, heroicons, Phoenix variants
recommender/                     # Python recommendation engine
  api.py                             # FastAPI app (health, game recs, user recs)
  pyproject.toml                     # Python dependencies
  main.py                            # CLI test script
  explore.ipynb                      # Jupyter notebook
  src/
    db.py                            # Database connection and queries
    preprocess.py                    # Data cleaning, outlier capping, feature derivation
    features.py                      # Feature extraction and encoding
    similarity.py                    # Cosine similarity with edition filtering
    engine.py                        # RecommendationEngine orchestrator
    visualize.py                     # Matplotlib visualizations
```

## BGG Crawler

Crawls board game data from the BGG XML API2 in batches of 20, storing game metadata (ratings, categories, mechanics, designers, families, etc.).

### Manual Crawl

Via the admin crawler dashboard at [`localhost:4000/admin/crawler`](http://localhost:4000/admin/crawler) (superadmin only), or in iex:

```elixir
Recco.BoardGames.Crawler.start(max_id: 468_353)
```

### Weekly Scanner

An Oban cron job (`Recco.Workers.NewGameScanner`) runs every Monday at 3 AM to scan for newly added BGG entries. It starts from the highest `bgg_id` in the database and stops after 5 consecutive empty batches. Monitor at `/admin/jobs`.

A daily job (`Recco.Workers.SyncTaxonomy`) runs at 4 AM to extract distinct categories and mechanics from crawled game data into dedicated lookup tables, powering the multi-select filter dropdowns.

## Recommendation Engine

Content-based recommendation using cosine similarity on game feature vectors.

### Features Used
- **Numeric** (MinMax scaled): player count, playtime, min age, complexity weight
- **Categorical** (one-hot encoded): categories, mechanics, families

### Preprocessing Pipeline
- Outlier capping (playtime <= 1440 min, players <= 100, etc.)
- Drops pre-1900 entries
- Filters games with < 30 ratings
- Adds derived features: decade, rating tier, popularity tier, playtime/player range

### Edition Filtering
Recommendations exclude other editions/versions of the same game using BGG's `"Game: X"` family tag.

### User Profile Recommendations
Accepts a dict of `{bgg_id: rating}` pairs, builds a weighted average feature vector (the user's "ideal game"), and ranks all games by cosine similarity to that profile.

### FastAPI Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Engine status and game count |
| `GET` | `/games/{bgg_id}/recommendations?top_n=10` | Similar games (1-50) |
| `POST` | `/users/recommendations?top_n=20` | User recommendations (body: `{ratings: {bgg_id: score}}`) |

## Development

### Common Commands

```bash
mix setup                    # Full project setup
mix phx.server               # Start dev server
iex -S mix phx.server        # Start with interactive shell
mix test                     # Run all tests (203 tests)
mix precommit                # Compile (warnings-as-errors) + format + test
mix credo --strict           # Static analysis
mix dialyzer                 # Type checking
mix ecto.gen.migration name  # Generate a migration
mix ecto.migrate             # Run pending migrations
```

### Makefile

```bash
make up              # Start Docker Postgres (port 5460)
make down            # Stop Docker Postgres
make dev-api         # Start infra + setup + dev server
make dev-recommender # Start FastAPI recommender (port 8000)
make test            # Start infra + run tests
```

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | (dev.exs) | Postgres connection (production) |
| `SECRET_KEY_BASE` | (dev.exs) | Cookie signing (production) |
| `PHX_HOST` | `localhost` | Public hostname |
| `PORT` | `4000` | HTTP port |
| `RECOMMENDER_URL` | `http://localhost:8000` | FastAPI recommender URL |
| `BGG_BEARER_TOKEN` | — | BGG API auth token |
| `BACKUP_PATH` | — | Enables weekly `pg_dump` backup worker (prod) |
| `ALERT_RECIPIENTS` | — | Comma-separated emails for observability alerts (prod). Falls back to `Logger.error` when unset |
| `CSP_MODE` | — | Set to `enforce` to flip CSP out of Report-Only in prod (default is Report-Only) |
| `MAILER_ADAPTER` | `resend` | Swoosh adapter: `resend` or `brevo` |
| `MAILER_API_KEY` | — | Required in prod for the selected adapter |

## Key Dependencies

| Dependency | Purpose |
|---|---|
| `phoenix` ~> 1.8 | Web framework |
| `phoenix_live_view` ~> 1.0 | Real-time UI |
| `ecto_sql` + `postgrex` | Database |
| `bcrypt_elixir` ~> 3.0 | Password hashing |
| `hammer` ~> 7.3 | Rate limiting (ETS backend) |
| `cachex` ~> 4.0 | Hot-read caching (taxonomy, counters, popular-listing) |
| `oban` ~> 2.19 | Background jobs |
| `bandit` | HTTP server |
| `req` | HTTP client |
| `sweet_xml` | XML parsing (BGG API) |
| `telemetry_ui` | Metrics dashboard |
| `logger_json` ~> 7.0 | Structured logs (prod) |
| `swoosh` | Transactional + alert emails |
| `joken` | JWT verification |
| `corsica` | CORS |
| `credo` | Static analysis |
| `dialyxir` | Type checking |
| `excoveralls` | Test coverage |
| `ex_machina` | Test factories |
| `lazy_html` | LiveView test support |
