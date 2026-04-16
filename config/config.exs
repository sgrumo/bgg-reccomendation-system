import Config

config :recco,
  ecto_repos: [Recco.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  token_verifier: Recco.Auth.Token,
  recommender_url: "http://localhost:8000",
  recommender_client: Recco.Recommender.HttpClient

config :recco, ReccoWeb.Gettext,
  default_locale: "en",
  locales: ~w(en it)

config :recco, Recco.Mailer, adapter: Swoosh.Adapters.Local

config :swoosh, :api_client, Swoosh.ApiClient.Finch

config :recco, ReccoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: ReccoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Recco.PubSub,
  live_view: [signing_salt: "8hHPku3H"]

config :recco, Oban,
  repo: Recco.Repo,
  queues: [default: 1],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * 1", Recco.Workers.NewGameScanner},
       {"0 4 * * *", Recco.Workers.SyncTaxonomy},
       {"0 2 * * 0", Recco.Workers.DatabaseBackup}
     ]}
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# esbuild
config :esbuild,
  version: "0.21.5",
  recco: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# tailwind
config :tailwind,
  version: "3.4.13",
  recco: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
