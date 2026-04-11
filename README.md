# Recco

Board game recommendation system powered by data crawled from [BoardGameGeek](https://boardgamegeek.com/). Phoenix 1.8 LiveView platform with a Python-based content-based recommendation engine.

## Features

- **Browse & Search** — explore ~468K board games with full-text search, category/mechanic filters, sorting, and pagination
- **User Accounts** — session-based auth with registration, login, role-based access (base user / superadmin)
- **Ratings** — rate games 1-10 from the game detail page, manage ratings from "My Ratings"
- **Recommendations** — personalised "For You" page powered by your ratings, plus "Similar Games" on each game detail page
- **Preferences** — set preferred player count, weight, and playtime ranges
- **Admin Dashboard** — user management with stats, background job monitoring, crawler control, telemetry metrics
- **Mobile-first** — responsive layouts, hamburger menu with focus trapping, accessible navigation

## Stack

### Backend (Elixir/Phoenix)
- **Elixir** ~> 1.19, **Phoenix** ~> 1.8, **Phoenix LiveView** ~> 1.0
- **Ecto** with PostgreSQL (binary UUIDs, UTC datetime timestamps)
- **Bandit** as HTTP server
- **Oban** for background job scheduling
- **bcrypt_elixir** for password hashing
- **esbuild** + **Tailwind CSS** for asset bundling (no Node.js)
- **Joken** for JWT verification (API), **Corsica** for CORS

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
| `/admin` | Dashboard (user count, game count, total ratings) |
| `/admin/users` | User list with search, rating counts |
| `/admin/users/:id` | User detail with stats, ratings, delete |
| `/admin/jobs` | Oban background job monitoring |
| `/admin/crawler` | BGG crawler control (start/stop, progress) |
| `/admin/metrics` | TelemetryUI metrics dashboard |

### API

| Route | Pipeline | Description |
|---|---|---|
| `/health` | — | Health check |
| `/api/*` | `:api` | Public JSON endpoints |
| `/api/*` | `:api` + `:authenticated` | Protected JSON endpoints (JWT Bearer) |

## Project Structure

```
lib/
  recco/                         # Core business logic (contexts)
    accounts.ex                      # Users: register, auth, sessions, admin listing/delete
    accounts/
      user.ex                        # User schema (email, username, password, role)
      user_token.ex                  # Session token schema (60-day expiry)
      user_rating.ex                 # Rating schema (user + game, score 1-10)
      user_preference.ex             # Preference schema (categories, mechanics, ranges)
    board_games.ex                   # Games: CRUD, search/filter/paginate, batch lookups
    board_games/
      board_game.ex                  # BoardGame schema (BGG data, JSONB fields)
      bgg_api.ex                     # BGG XML API client
      crawler.ex                     # GenServer-based BGG crawler
      crawl_state.ex                 # Crawler progress tracking
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
  recco_web/                     # Web layer
    endpoint.ex                      # HTTP endpoint (sessions, CORS, static)
    router.ex                        # Routes (public, auth, admin, API)
    telemetry.ex                     # Telemetry metrics
    components/
      core_components.ex             # Shared UI: input, flash, icon
      navigation.ex                  # Navbar, mobile menu, admin sidebar, user menu
      layouts.ex                     # Layout module (embeds templates)
      layouts/
        root.html.heex               # HTML shell (skip-to-content, assets)
        app.html.heex                # Main layout (navbar + content)
        public.html.heex             # Minimal layout (login/register)
        admin.html.heex              # Admin layout (sidebar + content)
    controllers/
      user_session_controller.ex     # Login/logout (HTML)
      user_registration_controller.ex # Registration (HTML)
      fallback_controller.ex         # Error tuple → HTTP response
    plugs/
      auth.ex                        # JWT Bearer token verification (API)
      fetch_current_user.ex          # Session → :current_user assign (browser)
    live/
      user_auth.ex                   # LiveView on_mount hooks (4 variants)
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
        dashboard_live.ex            # Admin dashboard (/admin)
        user_live/
          index.ex                   # User management (/admin/users)
          show.ex                    # User detail + stats + delete (/admin/users/:id)
        job_live.ex                  # Oban job monitoring (/admin/jobs)
        crawler_live.ex              # Crawler control (/admin/crawler)
    health/
      router.ex                      # GET /health
      checks.ex                      # Health check implementations
assets/
  js/
    app.js                           # LiveSocket setup, hook registration
    hooks/
      mobile_menu.js                 # Focus trapping, escape-to-close
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
mix test                     # Run all tests (112 tests)
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

## Key Dependencies

| Dependency | Purpose |
|---|---|
| `phoenix` ~> 1.8 | Web framework |
| `phoenix_live_view` ~> 1.0 | Real-time UI |
| `ecto_sql` + `postgrex` | Database |
| `bcrypt_elixir` ~> 3.0 | Password hashing |
| `oban` ~> 2.19 | Background jobs |
| `bandit` | HTTP server |
| `req` | HTTP client |
| `sweet_xml` | XML parsing (BGG API) |
| `telemetry_ui` | Metrics dashboard |
| `joken` | JWT verification |
| `corsica` | CORS |
| `credo` | Static analysis |
| `dialyxir` | Type checking |
| `excoveralls` | Test coverage |
| `ex_machina` | Test factories |
| `lazy_html` | LiveView test support |
