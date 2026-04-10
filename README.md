# Recco

Board game recommendation system powered by data crawled from [BoardGameGeek](https://boardgamegeek.com/). Phoenix 1.8 backend with a Python-based content-based recommendation engine.

## Stack

### Backend (Elixir/Phoenix)
- **Elixir** ~> 1.19, **Phoenix** ~> 1.8
- **Ecto** with PostgreSQL (binary UUIDs, UTC datetime timestamps)
- **Bandit** as HTTP server
- **Oban** for background job scheduling
- **esbuild** + **Tailwind CSS** for asset bundling (no Node.js)
- **Joken** for JWT verification, **Corsica** for CORS

### Recommendation Engine (Python)
- **pandas** + **scikit-learn** for feature engineering and similarity
- **SQLAlchemy** + **psycopg2** for database access
- **matplotlib** for visualization

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

Start the server:

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
jupyter notebook explore.ipynb
```

## Project Structure

```
lib/
  recco/                     # Core business logic
    application.ex               # OTP supervision tree
    repo.ex                      # Ecto Repo
    errors.ex                    # Shared typed error tuples
    auth/
      token.ex                   # JWT verification (Joken)
      token_mock.ex              # Test mock (swapped via config)
    board_games/
      board_game.ex              # BoardGame schema (BGG data)
      bgg_api.ex                 # BGG XML API client
      crawler.ex                 # GenServer-based BGG crawler
      crawl_state.ex             # Crawler progress tracking
    workers/
      new_game_scanner.ex        # Oban worker: weekly scan for new BGG entries
  recco_web/                 # Web layer
    endpoint.ex                  # HTTP endpoint
    router.ex                    # Routes (API, browser, admin, dev)
    telemetry.ex                 # Telemetry metrics (standard + TelemetryUI)
    controllers/
    plugs/
    live/
      auth_hook.ex               # LiveView session auth
      crawler_live.ex            # Crawler dashboard (dev only)
    health/
      router.ex                  # GET /health
      checks.ex                  # Health check implementations
recommender/                 # Python recommendation engine
  pyproject.toml                 # Python dependencies
  main.py                        # CLI test script
  explore.ipynb                  # Jupyter notebook for exploration
  src/
    db.py                        # Database connection and queries
    preprocess.py                # Data cleaning, outlier capping, feature derivation
    features.py                  # Feature extraction and encoding
    similarity.py                # Cosine similarity with edition filtering
    engine.py                    # RecommendationEngine orchestrator
    visualize.py                 # Matplotlib visualizations
test/
  support/
    conn_case.ex                 # HTTP test case with auth helpers
    data_case.ex                 # DB test case (Ecto sandbox)
    factory.ex                   # ExMachina factory definitions
```

## BGG Crawler

Crawls board game data from the BGG XML API2 in batches of 20, storing game metadata (ratings, categories, mechanics, designers, families, etc.).

### Manual Crawl

Via the LiveView dashboard at [`localhost:4000/dev/crawler`](http://localhost:4000/dev/crawler) (dev only), or in iex:

```elixir
Recco.BoardGames.Crawler.start(max_id: 468_353)
```

### Weekly Scanner

An Oban cron job (`Recco.Workers.NewGameScanner`) runs every Monday at 3 AM to scan for newly added BGG entries. It starts from the highest `bgg_id` in the database and stops after 5 consecutive empty batches.

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

## Architecture

### Context Pattern

Strict separation between core (`lib/recco/`) and web (`lib/recco_web/`). Controllers never touch `Repo` directly.

### Error Flow

`Recco.Errors` defines typed error tuples. All context functions return `{:ok, result} | Recco.Errors.t()`. The `FallbackController` maps error atoms to HTTP status codes.

### Authentication

Token verification swappable via config (`Recco.Auth.Token` / `Recco.Auth.TokenMock`). LiveView uses session-based auth via `ReccoWeb.Live.AuthHook`.

### Router

| Layer | Pipeline | Description |
|---|---|---|
| `/health` | — | Health check (forwarded to `Health.Router`) |
| `/api` | `:api` | Public JSON endpoints |
| `/api` | `:api`, `:authenticated` | Protected JSON endpoints |
| `/admin` | `:browser` | Admin LiveViews (auth hook) |
| `/dev/crawler` | `:browser` | Crawler dashboard (dev only) |
| `/dev/metrics` | `:browser` | TelemetryUI metrics (dev only) |

### OTP Supervision Tree

```
Telemetry → Repo → [TelemetryUI] → Oban → DNSCluster → PubSub → Registry → DynamicSupervisor → Endpoint
```

## Development

### Common Commands

```bash
mix setup                    # Full project setup
mix phx.server               # Start dev server
iex -S mix phx.server        # Start with interactive shell
mix test                     # Run all tests
mix precommit                # Compile (warnings-as-errors) + format + test
mix credo --strict           # Static analysis
mix dialyzer                 # Type checking
mix ecto.gen.migration name  # Generate a migration
mix ecto.migrate             # Run pending migrations
```

### Makefile

```bash
make up       # Start Docker Postgres (port 5460)
make down     # Stop Docker Postgres
make dev-api  # Start infra + setup + dev server
make test     # Start infra + run tests
```

## Observability

- **Health check:** `GET /health` via `plug_checkup`
- **Metrics dashboard:** `/dev/metrics` via `telemetry_ui` (dev only)
- **Telemetry events:** Phoenix + Ecto telemetry in `ReccoWeb.Telemetry`

## Key Dependencies

| Dependency | Purpose |
|---|---|
| `phoenix` ~> 1.8 | Web framework |
| `phoenix_live_view` ~> 1.0 | Real-time UI |
| `ecto_sql` + `postgrex` | Database |
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
