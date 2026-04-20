defmodule Recco.Ratings do
  @moduledoc """
  The Ratings context.
  """

  import Ecto.Query

  require Logger

  alias Recco.Accounts.UserRating
  alias Recco.BoardGames
  alias Recco.BoardGames.BggApi
  alias Recco.Errors
  alias Recco.Repo

  @spec rate_game(String.t(), String.t(), map()) :: {:ok, UserRating.t()} | Errors.t(map())
  def rate_game(user_id, board_game_id, attrs) do
    case Repo.get_by(UserRating, user_id: user_id, board_game_id: board_game_id) do
      nil ->
        %UserRating{user_id: user_id, board_game_id: board_game_id}

      existing ->
        existing
    end
    |> UserRating.changeset(attrs)
    |> Repo.insert_or_update()
    |> Errors.handle_changeset_error()
  end

  @spec delete_rating(String.t(), String.t()) :: :ok | Errors.t()
  def delete_rating(user_id, board_game_id) do
    case Repo.get_by(UserRating, user_id: user_id, board_game_id: board_game_id) do
      nil ->
        {:error, :not_found}

      rating ->
        Repo.delete!(rating)
        :ok
    end
  end

  @spec get_user_rating(String.t(), String.t()) :: UserRating.t() | nil
  def get_user_rating(user_id, board_game_id) do
    Repo.get_by(UserRating, user_id: user_id, board_game_id: board_game_id)
  end

  @spec list_user_ratings(String.t()) :: [UserRating.t()]
  def list_user_ratings(user_id) do
    from(r in UserRating,
      where: r.user_id == ^user_id,
      join: bg in assoc(r, :board_game),
      preload: [board_game: bg],
      order_by: [desc: r.updated_at]
    )
    |> Repo.all()
  end

  @spec user_ratings_as_map(String.t()) :: %{integer() => float()}
  def user_ratings_as_map(user_id) do
    from(r in UserRating,
      join: bg in assoc(r, :board_game),
      where: r.user_id == ^user_id,
      select: {bg.bgg_id, r.score}
    )
    |> Repo.all()
    |> Map.new()
  end

  @spec user_scores_map(String.t() | nil, [String.t()]) :: %{String.t() => float()}
  def user_scores_map(nil, _game_ids), do: %{}
  def user_scores_map(_user_id, []), do: %{}

  def user_scores_map(user_id, game_ids) do
    from(r in UserRating,
      where: r.user_id == ^user_id and r.board_game_id in ^game_ids,
      select: {r.board_game_id, r.score}
    )
    |> Repo.all()
    |> Map.new()
  end

  @spec import_bgg_ratings(String.t(), String.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def import_bgg_ratings(user_id, bgg_username) do
    Logger.info("Starting BGG import for user #{user_id}, BGG username: #{bgg_username}")

    with {:ok, collection} <- BggApi.fetch_collection(bgg_username) do
      Logger.info("Fetched #{length(collection)} rated items from BGG")

      valid_items = Enum.filter(collection, & &1.score)
      bgg_ids = Enum.map(valid_items, & &1.bgg_id)
      games_map = BoardGames.get_board_games_by_bgg_ids(bgg_ids)

      Logger.info(
        "Matched #{map_size(games_map)} of #{length(valid_items)} BGG games to local database"
      )

      existing_game_ids =
        from(r in UserRating,
          where: r.user_id == ^user_id,
          select: r.board_game_id
        )
        |> Repo.all()
        |> MapSet.new()

      imported =
        valid_items
        |> Enum.filter(&Map.has_key?(games_map, &1.bgg_id))
        |> Enum.reject(fn item ->
          game = Map.fetch!(games_map, item.bgg_id)
          MapSet.member?(existing_game_ids, game.id)
        end)
        |> Enum.reduce(0, fn item, count ->
          game = Map.fetch!(games_map, item.bgg_id)
          {:ok, _} = rate_game(user_id, game.id, %{score: item.score})
          count + 1
        end)

      Logger.info("BGG import complete: #{imported} ratings imported")
      {:ok, imported}
    end
  end

  @spec count_user_ratings(String.t()) :: non_neg_integer()
  def count_user_ratings(user_id) do
    from(r in UserRating, where: r.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  @spec average_user_score(String.t()) :: float() | nil
  def average_user_score(user_id) do
    from(r in UserRating, where: r.user_id == ^user_id)
    |> Repo.aggregate(:avg, :score)
  end

  @spec total_ratings_count() :: non_neg_integer()
  def total_ratings_count do
    Repo.aggregate(UserRating, :count)
  end

  @spec user_stats(String.t()) :: map()
  def user_stats(user_id) do
    query = from(r in UserRating, where: r.user_id == ^user_id)

    %{
      rating_count: Repo.aggregate(query, :count),
      average_score: Repo.aggregate(query, :avg, :score),
      highest_score: Repo.aggregate(query, :max, :score),
      lowest_score: Repo.aggregate(query, :min, :score)
    }
  end
end
