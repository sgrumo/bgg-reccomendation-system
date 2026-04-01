# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Averziano is a Phoenix 1.8 application (JSON API + LiveView) backed by PostgreSQL with Ecto. Uses Bandit as HTTP server, binary UUIDs as primary keys, and esbuild/Tailwind for asset bundling.

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
- `make up` / `make down` — start/stop Docker Postgres
- `make dev-api` — start infra + setup + dev server

## Architecture

### Context Pattern

Strict separation: `lib/averziano/` (business logic) vs `lib/averziano_web/` (web layer). Controllers never touch `Repo` directly — all DB access goes through context modules.

### Error Flow

`Averziano.Errors` defines typed error tuples (`{:error, reason}` or `{:error, reason, details}`). All context functions return `{:ok, result} | Errors.t()`. The `FallbackController` maps error atoms to HTTP status codes — controllers use `action_fallback` and return error tuples directly.

### Auth

Swappable token verification via config: `config :averziano, token_verifier: Averziano.Auth.Token` (production) / `Averziano.Auth.TokenMock` (test). The `AverzianoWeb.Plugs.Auth` plug reads config at runtime. LiveView auth uses session-based `on_mount` hook (`AverzianoWeb.Live.AuthHook`).

### Router Organization

Pipelines: `:api`, `:browser`, `:authenticated`. Health check forwarded to `AverzianoWeb.Health.Router`. Scopes: public API, authenticated API, admin (browser + LiveView with auth hook).

### Web Module Dispatch

`AverzianoWeb` defines `:controller` (JSON-only) and `:html_controller` (HTML+JSON) quoted blocks, plus `:live_view`, `:live_component`, `:html`.

### OTP Supervision

Flat `one_for_one`: Telemetry -> Repo -> [TelemetryUI] -> DNSCluster -> PubSub -> Registry -> DynamicSupervisor -> Endpoint. Registry + DynamicSupervisor for per-session GenServer processes.

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

## Testing Principles

- Test observable behavior, not implementation details
- Avoid overlapping tests and subtle duplication
- Ensure every test actually runs (no dead conditional paths)
- Keep tests simple and fast
