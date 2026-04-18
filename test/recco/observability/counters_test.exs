defmodule Recco.Observability.CountersTest do
  use ExUnit.Case, async: false

  alias Recco.Observability.Counters

  setup do
    # Ensure a clean table for each test; the GenServer is already started
    # by the application.
    _ = Counters.snapshot_and_reset()
    :ok
  end

  test "incr accumulates counts" do
    Counters.incr(:crawler_error)
    Counters.incr(:crawler_error)
    Counters.incr(:bgg_429)

    assert %{crawler_error: 2, bgg_429: 1} = Counters.snapshot()
  end

  test "snapshot_and_reset drains the table" do
    Counters.incr(:auth_failed)
    assert %{auth_failed: 1} = Counters.snapshot_and_reset()
    assert Counters.snapshot() == %{}
  end
end
