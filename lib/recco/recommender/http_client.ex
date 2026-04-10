defmodule Recco.Recommender.HttpClient do
  @moduledoc """
  HTTP client for the FastAPI recommender service.
  """

  @type recommendation :: %{bgg_id: integer(), name: String.t(), score: float()}

  @spec game_recommendations(integer(), keyword()) ::
          {:ok, [recommendation()]} | {:error, atom()}
  def game_recommendations(bgg_id, opts \\ []) do
    top_n = Keyword.get(opts, :top_n, 10)
    url = "#{base_url()}/games/#{bgg_id}/recommendations?top_n=#{top_n}"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, normalize_recommendations(body)}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      _ ->
        {:error, :service_unavailable}
    end
  end

  @spec user_recommendations(%{integer() => float()}, keyword()) ::
          {:ok, [recommendation()]} | {:error, atom()}
  def user_recommendations(ratings, opts \\ []) do
    top_n = Keyword.get(opts, :top_n, 20)
    url = "#{base_url()}/users/recommendations?top_n=#{top_n}"

    string_ratings =
      ratings
      |> Enum.map(fn {bgg_id, score} -> {to_string(bgg_id), score} end)
      |> Map.new()

    case Req.post(url, json: %{ratings: string_ratings}) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, normalize_recommendations(body)}

      {:ok, %{status: 422}} ->
        {:error, :unprocessable_entity}

      _ ->
        {:error, :service_unavailable}
    end
  end

  defp normalize_recommendations(body) when is_list(body) do
    Enum.map(body, fn item ->
      %{
        bgg_id: item["bgg_id"],
        name: item["name"],
        score: item["score"]
      }
    end)
  end

  defp base_url do
    Application.fetch_env!(:recco, :recommender_url)
  end
end
