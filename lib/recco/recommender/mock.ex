defmodule Recco.Recommender.Mock do
  @moduledoc """
  Test mock for the recommender client.
  """

  @type recommendation :: %{bgg_id: integer(), name: String.t(), score: float()}

  @spec game_recommendations(integer(), keyword()) ::
          {:ok, [recommendation()]} | {:error, atom()}
  def game_recommendations(_bgg_id, _opts \\ []) do
    {:ok,
     [
       %{bgg_id: 1, name: "Similar Game 1", score: 0.95},
       %{bgg_id: 2, name: "Similar Game 2", score: 0.88}
     ]}
  end

  @spec user_recommendations(%{integer() => float()}, keyword()) ::
          {:ok, [recommendation()]} | {:error, atom()}
  def user_recommendations(_ratings, _opts \\ []) do
    {:ok,
     [
       %{bgg_id: 10, name: "Recommended Game 1", score: 0.92},
       %{bgg_id: 20, name: "Recommended Game 2", score: 0.85}
     ]}
  end

  @spec search(String.t(), keyword()) :: {:ok, [recommendation()]} | {:error, atom()}
  def search(_query, _opts \\ []) do
    {:ok,
     [
       %{bgg_id: 100, name: "Search Result 1", score: 0.91},
       %{bgg_id: 200, name: "Search Result 2", score: 0.83}
     ]}
  end

  @spec refresh_embeddings() :: {:ok, non_neg_integer()} | {:error, atom()}
  def refresh_embeddings do
    {:ok, 0}
  end
end
