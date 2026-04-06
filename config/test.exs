import Config

config :recco, Recco.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "recco_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :recco, ReccoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "EVEX4cfEOFNvRIZ20m+9b+NWkfb6vzDcAUukWY1TS6LEwuWcTLCDfu4wqcn1hZLs",
  server: false

config :recco, token_verifier: Recco.Auth.TokenMock
config :recco, bgg_http_client: Recco.BoardGames.BggApi.MockClient

config :recco, Oban, testing: :inline

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix,
  sort_verified_routes_query_params: true
