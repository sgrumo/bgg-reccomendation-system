defmodule Recco.Observability.Alert do
  @moduledoc """
  Delivers alerts by email via Swoosh. Recipients come from the
  `:alert_recipients` application config (list of email strings) or the
  `ALERT_RECIPIENTS` env var (comma-separated). If no recipients are
  configured, falls back to `Logger.error` so alerts are never silently
  dropped during local development.

  Dedup is handled by the caller (`Recco.Workers.AlertDispatcher`).
  """

  import Swoosh.Email
  require Logger

  alias Recco.Mailer

  @sender {"Recco Alerts", "noreply@recco.app"}

  @type rule :: atom()

  @spec deliver(rule(), String.t()) :: :ok
  def deliver(rule, message) do
    case recipients() do
      [] ->
        Logger.error("[alert:#{rule}] #{message}")
        :ok

      [_ | _] = to ->
        send_email(to, rule, message)
    end
  end

  defp send_email(to, rule, message) do
    email =
      new()
      |> to(Enum.map(to, &{"", &1}))
      |> from(@sender)
      |> subject("[Recco alert] #{rule}")
      |> text_body("""
      #{message}

      Rule: #{rule}
      Fired at: #{DateTime.utc_now() |> DateTime.to_iso8601()}
      """)

    case Mailer.deliver(email) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to deliver alert #{rule}: #{inspect(reason)}")
        :ok
    end
  end

  defp recipients do
    case Application.get_env(:recco, :alert_recipients) do
      list when is_list(list) -> list
      binary when is_binary(binary) -> parse_recipients(binary)
      _ -> []
    end
  end

  defp parse_recipients(binary) do
    binary
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
