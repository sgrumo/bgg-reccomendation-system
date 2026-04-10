defmodule Recco.Recommender do
  @moduledoc """
  Context for fetching recommendations from the FastAPI recommender service.
  """

  alias Recco.BoardGames
  alias Recco.Ratings

  @type recommendation :: %{bgg_id: integer(), name: String.t(), score: float()}

  @spec game_recommendations(integer(), keyword()) ::
          {:ok, [recommendation()]} | {:error, atom()}
  def game_recommendations(bgg_id, opts \\ []) do
    client().game_recommendations(bgg_id, opts)
  end

  @spec user_recommendations(String.t(), keyword()) ::
          {:ok, [recommendation()]} | {:error, atom()}
  def user_recommendations(user_id, opts \\ []) do
    ratings = Ratings.user_ratings_as_map(user_id)

    if map_size(ratings) == 0 do
      {:ok, []}
    else
      client().user_recommendations(ratings, opts)
    end
  end

  @spec enrich_with_games([recommendation()]) :: [map()]
  def enrich_with_games(recommendations) do
    bgg_ids = Enum.map(recommendations, & &1.bgg_id)
    games_by_bgg_id = BoardGames.get_board_games_by_bgg_ids(bgg_ids)

    Enum.map(recommendations, fn rec ->
      Map.put(rec, :game, Map.get(games_by_bgg_id, rec.bgg_id))
    end)
  end

  defp client do
    Application.fetch_env!(:recco, :recommender_client)
  end
end
