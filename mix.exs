defmodule Recco.MixProject do
  use Mix.Project

  def project do
    [
      app: :recco,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :unknown, :unmatched_returns, :underspecs]
      ]
    ]
  end

  def application do
    [
      mod: {Recco.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},

      # Database
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},

      # HTTP server
      {:bandit, "~> 1.5"},

      # Auth
      {:bcrypt_elixir, "~> 3.0"},
      {:joken, "~> 2.6"},

      # Rate limiting
      {:hammer, "~> 7.3"},

      # CORS
      {:corsica, "~> 2.1"},

      # Health & Metrics
      {:plug_checkup, "~> 0.6"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_ui, "~> 5.3"},

      # Assets
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},

      # Jobs
      {:oban, "~> 2.19"},

      # Email
      {:swoosh, "~> 1.17"},
      {:finch, "~> 0.19"},

      # Utilities
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:req, "~> 0.5"},
      {:sweet_xml, "~> 0.7"},

      # Static analysis
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

      # Test
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_machina, "~> 2.8", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind recco", "esbuild recco"],
      "assets.deploy": [
        "tailwind recco --minify",
        "esbuild recco --minify",
        "phx.digest"
      ]
    ]
  end
end
