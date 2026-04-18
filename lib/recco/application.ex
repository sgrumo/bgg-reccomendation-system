defmodule Recco.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Recco.Observability.attach_handlers()

    children =
      [
        ReccoWeb.Telemetry,
        Recco.Repo,
        telemetry_ui_child(),
        {Oban, Application.fetch_env!(:recco, Oban)},
        {DNSCluster, query: Application.get_env(:recco, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Recco.PubSub},
        {Registry, keys: :unique, name: Recco.Registry},
        {DynamicSupervisor, name: Recco.DynamicSupervisor, strategy: :one_for_one},
        {Finch, name: Swoosh.Finch},
        {Recco.RateLimit, [clean_period: :timer.minutes(10)]},
        Recco.Observability.Counters,
        ReccoWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: Recco.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ReccoWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp telemetry_ui_child do
    if Application.get_env(:recco, :telemetry_ui_enabled, false) do
      {TelemetryUI, telemetry_ui_config()}
    end
  end

  defp telemetry_ui_config do
    [
      metrics: ReccoWeb.Telemetry.ui_metrics(),
      theme: %{title: "Recco Metrics"},
      backend: %TelemetryUI.Backend.EctoPostgres{repo: Recco.Repo}
    ]
  end
end
