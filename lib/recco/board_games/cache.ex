defmodule Recco.BoardGames.Cache do
  @moduledoc """
  Read-path cache for the BoardGames context. Three named Cachex instances:

    * `:bgg_taxonomy_cache` — categories + mechanics dropdowns (24 h TTL)
    * `:bgg_counters_cache` — board_game_count + max_bgg_id (60 s TTL)
    * `:bgg_popular_cache` — canonical default `/games` listing (10 min TTL)

  All access goes through `fetch/3`, which delegates to `Cachex.fetch/3` so
  cold-key lookups are serialized (no thundering herd). When the cache is
  disabled via `config :recco, cache_enabled: false` (test env default),
  every call executes the fallback directly — useful to avoid cross-test
  staleness without adding Cachex.clear calls everywhere.

  Invalidation is split per cache. `invalidate/1` clears a single cache;
  `invalidate_on_upsert/0` is throttled (~5 s per-cache) so that crawler
  batches inserting 20 rows at a time don't thrash the cache.
  """

  import Cachex.Spec

  @taxonomy :bgg_taxonomy_cache
  @counters :bgg_counters_cache
  @popular :bgg_popular_cache

  @throttle_table :bgg_cache_throttle
  @throttle_window_ms :timer.seconds(5)

  @type cache :: :taxonomy | :counters | :popular

  # Supervision

  @spec child_specs() :: [Supervisor.child_spec()]
  def child_specs do
    [
      cachex_spec(@taxonomy, :timer.hours(24)),
      cachex_spec(@counters, :timer.seconds(60)),
      cachex_spec(@popular, :timer.minutes(10))
    ]
  end

  defp cachex_spec(name, ttl_ms) do
    options = [
      expiration: expiration(default: ttl_ms),
      hooks: [hook(module: Cachex.Stats)]
    ]

    Supervisor.child_spec({Cachex, [name, options]}, id: name)
  end

  # Read path

  @spec fetch(cache(), term(), (-> term())) :: term()
  def fetch(cache, key, fallback) when is_function(fallback, 0) do
    if enabled?(), do: do_fetch(cache, key, fallback), else: fallback.()
  end

  defp do_fetch(cache, key, fallback) do
    case Cachex.fetch(cache_name(cache), key, fn _ -> {:commit, fallback.()} end) do
      {:ok, value} -> value
      {:commit, value} -> value
      {:error, _} -> fallback.()
    end
  end

  # Invalidation

  @spec invalidate(cache()) :: :ok
  def invalidate(cache) do
    if enabled?(), do: Cachex.clear(cache_name(cache))
    :ok
  end

  @spec invalidate_on_upsert() :: :ok
  def invalidate_on_upsert do
    if enabled?() and throttle_allow?(:upsert) do
      Cachex.clear(cache_name(:counters))
      Cachex.clear(cache_name(:popular))
    end

    :ok
  end

  @doc """
  Returns the Cachex.Stats payload for every managed cache. Safe to call
  when the cache is disabled — returns an empty map in that case.
  """
  @spec stats() :: %{cache() => map()}
  def stats do
    if enabled?(),
      do: Map.new([:taxonomy, :counters, :popular], &{&1, cache_stats(&1)}),
      else: %{}
  end

  defp cache_stats(cache) do
    case Cachex.stats(cache_name(cache)) do
      {:ok, value} -> value
      _ -> %{}
    end
  end

  # Internals

  defp cache_name(:taxonomy), do: @taxonomy
  defp cache_name(:counters), do: @counters
  defp cache_name(:popular), do: @popular

  defp enabled?, do: Application.get_env(:recco, :cache_enabled, true)

  defp throttle_allow?(key) do
    ensure_throttle_table()
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@throttle_table, key) do
      [{^key, last}] when now - last < @throttle_window_ms ->
        false

      _ ->
        :ets.insert(@throttle_table, {key, now})
        true
    end
  end

  defp ensure_throttle_table do
    case :ets.whereis(@throttle_table) do
      :undefined ->
        _ = :ets.new(@throttle_table, [:named_table, :public, :set])
        :ok

      _ ->
        :ok
    end
  end
end
