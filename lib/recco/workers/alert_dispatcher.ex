defmodule Recco.Workers.AlertDispatcher do
  @moduledoc """
  Runs every 5 minutes on Oban cron. Drains the observability counter
  table, queries Oban for job-state signals, evaluates alert rules, and
  delivers to `Recco.Observability.Alert` with a 30 minute per-rule
  dedup window.

  Dedup state is ETS-based — acceptable because a restart window (minutes)
  is much shorter than the dedup window (30 min), and worst case we
  redeliver a single alert after a deploy.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias Recco.Observability.{Alert, Counters}

  @dedup_table :recco_alert_dedup
  @dedup_window_ms :timer.minutes(30)

  @impl true
  @spec perform(Oban.Job.t()) :: :ok
  def perform(_job) do
    ensure_dedup_table()
    counters = Counters.snapshot_and_reset()
    oban_signals = oban_signals()

    evaluate_rules(counters, oban_signals)
    :ok
  end

  defp evaluate_rules(counters, oban) do
    rules(counters, oban)
    |> Enum.each(fn
      {rule, {:fire, message}} -> maybe_deliver(rule, message)
      {_rule, :skip} -> :ok
    end)
  end

  defp rules(counters, oban) do
    crawler_ok = Map.get(counters, :crawler_ok, 0)
    crawler_err = Map.get(counters, :crawler_error, 0)
    total = crawler_ok + crawler_err

    [
      {:crawler_error_rate, crawler_error_rule(total, crawler_err)},
      {:bgg_rate_limit, bgg_rate_limit_rule(Map.get(counters, :bgg_429, 0))},
      {:auth_failures, auth_failures_rule(Map.get(counters, :auth_failed, 0))},
      {:oban_exhausted, oban_exhausted_rule(oban)}
    ]
  end

  defp crawler_error_rule(total, errors) when total >= 5 and errors / total > 0.2 do
    {:fire,
     "Crawler error rate #{percent(errors, total)}% over last 5 min (#{errors}/#{total} batches)"}
  end

  defp crawler_error_rule(_total, _errors), do: :skip

  defp bgg_rate_limit_rule(count) when count > 5,
    do: {:fire, "BGG returned 429 #{count} times in last 5 min — consider backing off further"}

  defp bgg_rate_limit_rule(_), do: :skip

  defp auth_failures_rule(count) when count > 50,
    do: {:fire, "#{count} failed login attempts in last 5 min"}

  defp auth_failures_rule(_), do: :skip

  defp oban_exhausted_rule(%{discarded: n}) when n > 0,
    do: {:fire, "#{n} Oban job(s) discarded (exhausted retries) — check /admin/jobs"}

  defp oban_exhausted_rule(_), do: :skip

  defp oban_signals do
    import Ecto.Query

    fifteen_min_ago = DateTime.add(DateTime.utc_now(), -15 * 60, :second)

    Recco.Repo.one(
      from(j in "oban_jobs",
        where: j.state == "discarded" and j.discarded_at > ^fifteen_min_ago,
        select: %{discarded: count(j.id)}
      )
    ) || %{discarded: 0}
  end

  defp percent(_, 0), do: 0
  defp percent(part, total), do: trunc(part / total * 100)

  defp maybe_deliver(rule, message) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@dedup_table, rule) do
      [{^rule, last}] when now - last < @dedup_window_ms ->
        :ok

      _ ->
        :ets.insert(@dedup_table, {rule, now})
        Alert.deliver(rule, message)
    end
  end

  defp ensure_dedup_table do
    case :ets.whereis(@dedup_table) do
      :undefined ->
        _ = :ets.new(@dedup_table, [:named_table, :public, :set])
        :ok

      _ref ->
        :ok
    end
  end
end
