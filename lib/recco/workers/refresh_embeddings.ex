defmodule Recco.Workers.RefreshEmbeddings do
  @moduledoc """
  Oban worker that asks the recommender to re-embed board game rows whose
  embedding is missing (newly crawled) or stale (text changed — see the
  `board_games_clear_stale_embedding` trigger). Runs daily; the recommender
  performs the embedding in the background.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Recco.Recommender

  @impl true
  @spec perform(Oban.Job.t()) :: :ok | {:error, atom()}
  def perform(_job) do
    case Recommender.refresh_embeddings() do
      {:ok, pending} ->
        Logger.info("Triggered embedding refresh; #{pending} rows pending")
        :ok

      {:error, reason} ->
        Logger.warning("Embedding refresh failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
