defmodule Recco.Notifications.Discord do
  @moduledoc """
  Fire-and-forget Discord webhook notifier.

  Delivery runs under `Recco.Notifications.TaskSupervisor` so calling code is
  never blocked or affected by Discord failures. When `:discord_webhook_url`
  is unset the call is a no-op, which keeps dev/test setups free of external
  side effects.
  """

  require Logger

  @spec notify(map()) :: :ok
  def notify(payload) when is_map(payload) do
    case webhook_url() do
      url when is_binary(url) and url != "" ->
        Task.Supervisor.start_child(
          Recco.Notifications.TaskSupervisor,
          fn -> deliver(url, payload) end,
          restart: :temporary
        )

        :ok

      _ ->
        :ok
    end
  end

  defp deliver(url, payload) do
    case client().post(url, payload) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Discord notification failed: #{inspect(reason)}")
        :ok
    end
  end

  defp webhook_url, do: Application.get_env(:recco, :discord_webhook_url)
  defp client, do: Application.fetch_env!(:recco, :discord_client)
end
