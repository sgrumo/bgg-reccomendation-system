defmodule Recco.Workers.AlertDispatcherTest do
  use Recco.DataCase, async: false

  import ExUnit.CaptureLog
  import Swoosh.TestAssertions

  alias Recco.Observability.Counters
  alias Recco.Workers.AlertDispatcher

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :error)

    Counters.snapshot_and_reset()
    # Force log-based delivery (no recipients configured).
    Application.delete_env(:recco, :alert_recipients)

    # Reset dedup table between tests to avoid cross-test suppression.
    case :ets.whereis(:recco_alert_dedup) do
      :undefined -> :ok
      _ -> :ets.delete_all_objects(:recco_alert_dedup)
    end

    on_exit(fn -> Logger.configure(level: previous_level) end)

    :ok
  end

  test "fires crawler error-rate alert when threshold exceeded" do
    for _ <- 1..2, do: Counters.incr(:crawler_ok)
    for _ <- 1..4, do: Counters.incr(:crawler_error)

    log = capture_log(fn -> :ok = AlertDispatcher.perform(%Oban.Job{}) end)

    assert log =~ "[alert:crawler_error_rate]"
    assert log =~ "Crawler error rate"
  end

  test "fires BGG 429 alert when > 5 in window" do
    for _ <- 1..6, do: Counters.incr(:bgg_429)

    log = capture_log(fn -> :ok = AlertDispatcher.perform(%Oban.Job{}) end)

    assert log =~ "[alert:bgg_rate_limit]"
  end

  test "skips when no signals" do
    log = capture_log(fn -> :ok = AlertDispatcher.perform(%Oban.Job{}) end)
    refute log =~ "[alert:"
  end

  test "sends an email when recipients are configured" do
    Application.put_env(:recco, :alert_recipients, ["ops@example.com"])
    on_exit(fn -> Application.delete_env(:recco, :alert_recipients) end)

    for _ <- 1..6, do: Counters.incr(:bgg_429)
    :ok = AlertDispatcher.perform(%Oban.Job{})

    assert_email_sent(fn email ->
      assert email.to == [{"", "ops@example.com"}]
      assert email.subject == "[Recco alert] bgg_rate_limit"
      assert email.text_body =~ "BGG returned 429"
    end)
  end

  test "dedupes repeat alerts within the window" do
    for _ <- 1..6, do: Counters.incr(:bgg_429)
    log1 = capture_log(fn -> :ok = AlertDispatcher.perform(%Oban.Job{}) end)

    for _ <- 1..6, do: Counters.incr(:bgg_429)
    log2 = capture_log(fn -> :ok = AlertDispatcher.perform(%Oban.Job{}) end)

    assert log1 =~ "[alert:bgg_rate_limit]"
    refute log2 =~ "[alert:bgg_rate_limit]"
  end
end
