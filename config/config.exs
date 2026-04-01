import Config

config :recco,
  ecto_repos: [Recco.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :recco, ReccoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: ReccoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Recco.PubSub,
  live_view: [signing_salt: "8hHPku3H"]

config :recco, token_verifier: Recco.Auth.Token

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
