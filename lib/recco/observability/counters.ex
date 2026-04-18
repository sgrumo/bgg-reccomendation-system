defmodule Recco.Observability.Counters do
  @moduledoc """
  Small ETS table of rolling counters bumped from telemetry handlers and
  drained by the alert dispatcher. Intentionally simple — no sliding
  windows: every `snapshot_and_reset/0` call yields counts since the
  previous drain. Good enough when the dispatcher fires on a fixed cron.
  """

  use GenServer

  @table __MODULE__

  @type key ::
          :crawler_ok | :crawler_error | :bgg_429 | :bgg_error | :auth_failed | :auth_locked_out

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec incr(key()) :: :ok
  def incr(key) do
    if :ets.whereis(@table) != :undefined do
      _ = :ets.update_counter(@table, key, 1, {key, 0})
    end

    :ok
  end

  @spec snapshot_and_reset() :: %{key() => non_neg_integer()}
  def snapshot_and_reset do
    case :ets.whereis(@table) do
      :undefined ->
        %{}

      _ ->
        rows = :ets.tab2list(@table)
        :ets.delete_all_objects(@table)
        Map.new(rows)
    end
  end

  @doc """
  Non-destructive read of the current-window counts. Useful for UI that
  wants a live indicator without resetting the dispatcher's input.
  """
  @spec snapshot() :: %{key() => non_neg_integer()}
  def snapshot do
    case :ets.whereis(@table) do
      :undefined -> %{}
      _ -> Map.new(:ets.tab2list(@table))
    end
  end

  @impl true
  def init(:ok) do
    _ = :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    {:ok, %{}}
  end
end
