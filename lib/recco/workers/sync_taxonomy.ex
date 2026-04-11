defmodule Recco.Workers.SyncTaxonomy do
  @moduledoc """
  Oban worker that syncs distinct categories and mechanics from
  board_games JSONB into the lookup tables. Runs daily at 4 AM.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias Recco.BoardGames

  @impl true
  @spec perform(Oban.Job.t()) :: :ok
  def perform(_job) do
    BoardGames.sync_taxonomy()
    :ok
  end
end
