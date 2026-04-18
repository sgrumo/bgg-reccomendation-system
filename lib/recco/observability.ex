defmodule Recco.Observability do
  @moduledoc """
  Attaches `:telemetry` handlers that structure log events for failure-mode
  signals (crawler batch exceptions, Oban job exceptions, crawler error
  outcomes). Metrics are separately exposed via `ReccoWeb.Telemetry`.
  """

  require Logger

  alias Recco.Observability.Counters

  @handlers [
    {[:oban, :job, :exception], &__MODULE__.log_oban_exception/4},
    {[:recco, :crawler, :batch, :exception], &__MODULE__.log_crawler_exception/4},
    {[:recco, :crawler, :batch, :stop], &__MODULE__.log_crawler_stop/4},
    {[:recco, :bgg, :request, :stop], &__MODULE__.observe_bgg_request/4},
    {[:recco, :auth, :login, :stop], &__MODULE__.observe_login/4}
  ]

  @spec attach_handlers() :: :ok
  def attach_handlers do
    Enum.each(@handlers, fn {event, handler} ->
      _ = :telemetry.detach({__MODULE__, event})

      :ok =
        :telemetry.attach({__MODULE__, event}, event, handler, nil)
    end)

    :ok
  end

  @spec log_oban_exception(list(), map(), map(), term()) :: :ok
  def log_oban_exception(_event, measurements, meta, _config) do
    attempt = Map.get(meta, :attempt, 0)
    max_attempts = Map.get(meta, :max_attempts, 0)

    Logger.error(
      "Oban job exception",
      worker: Map.get(meta, :worker),
      queue: Map.get(meta, :queue),
      attempt: attempt,
      max_attempts: max_attempts,
      exhausted: attempt >= max_attempts,
      duration_ms: div(Map.get(measurements, :duration, 0), 1_000_000),
      kind: Map.get(meta, :kind),
      reason: inspect(Map.get(meta, :reason))
    )

    :ok
  end

  @spec log_crawler_exception(list(), map(), map(), term()) :: :ok
  def log_crawler_exception(_event, _measurements, meta, _config) do
    Logger.error(
      "Crawler batch exception",
      start_id: Map.get(meta, :start_id),
      end_id: Map.get(meta, :end_id),
      kind: Map.get(meta, :kind),
      reason: inspect(Map.get(meta, :reason))
    )

    :ok
  end

  @spec log_crawler_stop(list(), map(), map(), term()) :: :ok
  def log_crawler_stop(_event, measurements, %{status: :error} = meta, _config) do
    Counters.incr(:crawler_error)

    Logger.error(
      "Crawler batch error",
      start_id: Map.get(meta, :start_id),
      end_id: Map.get(meta, :end_id),
      reason: Map.get(meta, :reason),
      duration_ms: div(Map.get(measurements, :duration, 0), 1_000_000)
    )

    :ok
  end

  def log_crawler_stop(_event, _measurements, %{status: :ok}, _config) do
    Counters.incr(:crawler_ok)
    :ok
  end

  def log_crawler_stop(_event, _measurements, _meta, _config), do: :ok

  @spec observe_bgg_request(list(), map(), map(), term()) :: :ok
  def observe_bgg_request(_event, _measurements, %{status: 429}, _config) do
    Counters.incr(:bgg_429)
    :ok
  end

  def observe_bgg_request(_event, _measurements, %{status: :error}, _config) do
    Counters.incr(:bgg_error)
    :ok
  end

  def observe_bgg_request(_event, _measurements, _meta, _config), do: :ok

  @spec observe_login(list(), map(), map(), term()) :: :ok
  def observe_login(_event, _measurements, %{result: :invalid_credentials}, _config) do
    Counters.incr(:auth_failed)
    :ok
  end

  def observe_login(_event, _measurements, %{result: :locked_out}, _config) do
    Counters.incr(:auth_locked_out)
    :ok
  end

  def observe_login(_event, _measurements, _meta, _config), do: :ok
end
