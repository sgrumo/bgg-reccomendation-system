# Recco

Phoenix 1.8 template repository with JSON API + LiveView, PostgreSQL, and production-ready patterns.

## Stack

- **Elixir** ~> 1.19, **Phoenix** ~> 1.8
- **Ecto** with PostgreSQL (binary UUIDs, UTC datetime timestamps)
- **Bandit** as HTTP server
- **esbuild** + **Tailwind CSS** for asset bundling (no Node.js)
- **Jason** for JSON encoding
- **Joken** for JWT verification
- **Corsica** for CORS

## Getting Started

### Prerequisites

- Elixir ~> 1.19
- PostgreSQL (or Docker)

### Setup

Start the database:

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

## Project Structure

```
lib/
  recco/                 # Core business logic (contexts, schemas)
    application.ex           # OTP supervision tree
    repo.ex                  # Ecto Repo
    errors.ex                # Shared typed error tuples
    auth/
      token.ex               # JWT verification (Joken)
      token_mock.ex          # Test mock (swapped via config)
  recco_web/             # Web layer
    endpoint.ex              # HTTP endpoint (CORS, sessions, LiveView socket)
    router.ex                # Route definitions (API, browser, admin)
    controllers/
      fallback_controller.ex # Maps error tuples to HTTP responses
      error_json.ex          # Default JSON error rendering
    plugs/
      auth.ex                # Bearer token auth plug
    live/
      auth_hook.ex           # LiveView on_mount session auth
    health/
      router.ex              # GET /health via plug_checkup
      checks.ex              # Health check implementations
    components/
      core_components.ex     # Shared UI components (icon, input, flash)
      layouts.ex             # Layout module
      layouts/
        root.html.heex       # Root HTML layout
        app.html.heex        # App layout with flash
test/
  support/
    conn_case.ex             # HTTP test case with auth helpers
    data_case.ex             # DB test case (Ecto sandbox)
    channel_case.ex          # Channel test case
    factory.ex               # ExMachina factory definitions
```

## Architecture

### Context Pattern

Strict separation between core (`lib/recco/`) and web (`lib/recco_web/`). Controllers never touch `Repo` directly — all database access goes through context modules.

### Error Flow

`Recco.Errors` defines typed error tuples:

```elixir
{:error, :not_found}                    # Simple error
{:error, :unprocessable_entity, errors} # Error with details
```

All context functions return `{:ok, result} | Recco.Errors.t()`. The `FallbackController` maps error atoms to HTTP status codes, so controllers use `action_fallback ReccoWeb.FallbackController` and return error tuples directly.

### Authentication

Token verification is swappable via config:

```elixir
# config/config.exs (production)
config :recco, token_verifier: Recco.Auth.Token

# config/test.exs
config :recco, token_verifier: Recco.Auth.TokenMock
```

The `ReccoWeb.Plugs.Auth` plug reads the verifier from config at runtime, enabling mock injection in tests without Mox.

LiveView uses session-based auth via the `ReccoWeb.Live.AuthHook` `on_mount` callback.

### Router Organization

| Layer | Pipeline | Description |
|---|---|---|
| `/health` | — | Health check (forwarded to `Health.Router`) |
| `/api` | `:api` | Public JSON endpoints |
| `/api` | `:api`, `:authenticated` | Protected JSON endpoints |
| `/admin` | `:browser` | Admin LiveViews (`live_session` with auth hook) |

### Web Module Dispatch

`ReccoWeb` provides quoted blocks via `use ReccoWeb, :type`:

- `:controller` — JSON-only API controllers
- `:html_controller` — HTML + JSON controllers (admin, sessions)
- `:live_view` — LiveView modules
- `:live_component` — LiveView components
- `:html` — Phoenix HTML helpers

### OTP Supervision Tree

Flat `one_for_one` strategy:

```
Telemetry → Repo → [TelemetryUI] → DNSCluster → PubSub → Registry → DynamicSupervisor → Endpoint
```

`Registry` + `DynamicSupervisor` are included for per-session GenServer processes (real-time features).

## Development

### Common Commands

```bash
mix setup                    # Full project setup
mix phx.server               # Start dev server
iex -S mix phx.server        # Start with interactive shell
mix test                     # Run all tests
mix test path/to/test.exs    # Run a single test file
mix test path/to/test.exs:42 # Run test at specific line
mix test --failed            # Re-run failed tests
mix precommit                # Compile (warnings-as-errors) + format + test
mix credo --strict           # Static analysis
mix dialyzer                 # Type checking (first run builds PLT)
mix ecto.gen.migration name  # Generate a migration
mix ecto.migrate             # Run pending migrations
mix ecto.reset               # Drop + recreate + seed
```

### Makefile

```bash
make up       # Start Docker Postgres
make down     # Stop Docker Postgres
make dev-api  # Start infra + setup + dev server
make test     # Start infra + run tests
```

### Precommit

Always run before committing:

```bash
mix precommit
```

This runs compilation with `--warnings-as-errors`, unlocks unused deps, formats code, and runs the full test suite.

## Static Analysis

### Credo (strict mode)

Configured in `.credo.exs` with notable rules:

- `Readability.Specs` — every public function must have `@spec`
- `Refactor.ABCSize` max 40 — keeps functions small
- `MaxLineLength` 200
- `ModuleDoc` disabled
- `AliasUsage` — require aliases when nested > 1 and called > 2 times

### Dialyzer

Flags: `error_handling`, `unknown`, `unmatched_returns`, `underspecs`. PLT files cached in `priv/plts/` (gitignored).

## Testing

- **ExUnit** with **ExCoveralls** for coverage
- **ExMachina** for factories (`test/support/factory.ex`)
- Factory auto-imported in both `DataCase` and `ConnCase`
- Auth helpers in `ConnCase`: `authenticate(conn)`, `authenticate_superadmin(conn)`
- Test cases: `DataCase` (DB), `ConnCase` (HTTP), `ChannelCase` (WebSocket)
- Tests mirror source directory structure

## Observability

- **Health check:** `GET /health` via `plug_checkup` (checks database connectivity)
- **Metrics:** `telemetry_ui` for request counts/durations, DB query times, VM memory
- **Telemetry events:** Standard Phoenix + Ecto telemetry configured in `ReccoWeb.Telemetry`

## Key Dependencies

| Dependency | Purpose |
|---|---|
| `phoenix` ~> 1.8 | Web framework |
| `phoenix_live_view` ~> 1.0 | Real-time UI |
| `ecto_sql` + `postgrex` | Database |
| `bandit` | HTTP server |
| `jason` | JSON |
| `joken` | JWT verification |
| `corsica` | CORS |
| `req` | HTTP client |
| `plug_checkup` | Health checks |
| `telemetry_ui` | Metrics dashboard |
| `esbuild` | JS bundling |
| `tailwind` | CSS |
| `gettext` | i18n |
| `dns_cluster` | Clustering |
| `credo` | Static analysis |
| `dialyxir` | Type checking |
| `excoveralls` | Test coverage |
| `ex_machina` | Test factories |
