defmodule Recco.BoardGames.CacheTest do
  @moduledoc """
  Turns the cache back on (test env disables it by default) so we can
  exercise fetch, fallback serialization, and invalidation. Uses ets
  :clear at the Cachex layer to keep test runs independent.
  """
  use ExUnit.Case, async: false

  alias Recco.BoardGames.Cache

  setup do
    Application.put_env(:recco, :cache_enabled, true)
    Cache.invalidate(:taxonomy)
    Cache.invalidate(:counters)
    Cache.invalidate(:popular)

    on_exit(fn -> Application.put_env(:recco, :cache_enabled, false) end)

    :ok
  end

  test "fetch caches the fallback result" do
    counter = :counters.new(1, [:write_concurrency])
    :counters.put(counter, 1, 0)

    fallback = fn ->
      :counters.add(counter, 1, 1)
      :counters.get(counter, 1)
    end

    assert 1 = Cache.fetch(:counters, :sample, fallback)
    assert 1 = Cache.fetch(:counters, :sample, fallback)
    assert :counters.get(counter, 1) == 1
  end

  test "invalidate clears the cache" do
    Cache.fetch(:taxonomy, :categories, fn -> [:first] end)
    assert [:first] = Cache.fetch(:taxonomy, :categories, fn -> [:second] end)

    Cache.invalidate(:taxonomy)
    assert [:second] = Cache.fetch(:taxonomy, :categories, fn -> [:second] end)
  end

  test "invalidate_on_upsert throttles to at most one clear per window" do
    Cache.fetch(:counters, :board_game_count, fn -> 10 end)
    assert 10 = Cache.fetch(:counters, :board_game_count, fn -> 999 end)

    Cache.invalidate_on_upsert()
    assert 11 = Cache.fetch(:counters, :board_game_count, fn -> 11 end)

    # Immediate second call in the same window does NOT invalidate
    # (throttle should swallow it).
    Cache.invalidate_on_upsert()
    assert 11 = Cache.fetch(:counters, :board_game_count, fn -> 999 end)
  end

  test "fetch is a passthrough when the cache is disabled" do
    Application.put_env(:recco, :cache_enabled, false)

    counter = :counters.new(1, [:write_concurrency])
    :counters.put(counter, 1, 0)

    fallback = fn ->
      :counters.add(counter, 1, 1)
      :counters.get(counter, 1)
    end

    Cache.fetch(:counters, :sample, fallback)
    Cache.fetch(:counters, :sample, fallback)

    assert :counters.get(counter, 1) == 2
  end
end
