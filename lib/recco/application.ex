defmodule Recco.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        ReccoWeb.Telemetry,
        Recco.Repo,
        telemetry_ui_child(),
        {DNSCluster, query: Application.get_env(:recco, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Recco.PubSub},
        {Registry, keys: :unique, name: Recco.Registry},
        {DynamicSupervisor, name: Recco.DynamicSupervisor, strategy: :one_for_one},
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
      metrics: ReccoWeb.Telemetry.metrics(),
      theme: %{title: "Recco Metrics"},
      backend: %TelemetryUI.Backend.EctoPostgres{repo: Recco.Repo}
    ]
  end
end
