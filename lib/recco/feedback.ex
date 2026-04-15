defmodule Recco.Feedback do
  @moduledoc """
  The Feedback context for recommendation feedback (thumbs up/down).
  """

  import Ecto.Query

  alias Recco.Accounts.RecommendationFeedback
  alias Recco.Errors
  alias Recco.Repo

  @spec upsert_feedback(String.t(), String.t(), map()) ::
          {:ok, RecommendationFeedback.t()} | Errors.t(map())
  def upsert_feedback(user_id, board_game_id, attrs) do
    case Repo.get_by(RecommendationFeedback, user_id: user_id, board_game_id: board_game_id) do
      nil ->
        %RecommendationFeedback{user_id: user_id, board_game_id: board_game_id}

      existing ->
        existing
    end
    |> RecommendationFeedback.changeset(attrs)
    |> Repo.insert_or_update()
    |> Errors.handle_changeset_error()
  end

  @spec delete_feedback(String.t(), String.t()) :: :ok | Errors.t()
  def delete_feedback(user_id, board_game_id) do
    case Repo.get_by(RecommendationFeedback, user_id: user_id, board_game_id: board_game_id) do
      nil ->
        {:error, :not_found}

      feedback ->
        Repo.delete!(feedback)
        :ok
    end
  end

  @spec get_feedback(String.t(), String.t()) :: RecommendationFeedback.t() | nil
  def get_feedback(user_id, board_game_id) do
    Repo.get_by(RecommendationFeedback, user_id: user_id, board_game_id: board_game_id)
  end

  @spec user_feedback_map(String.t()) :: %{String.t() => boolean()}
  def user_feedback_map(user_id) do
    from(f in RecommendationFeedback,
      where: f.user_id == ^user_id,
      select: {f.board_game_id, f.positive}
    )
    |> Repo.all()
    |> Map.new()
  end

  @spec stats() :: map()
  def stats do
    total = Repo.aggregate(RecommendationFeedback, :count)

    positive =
      from(f in RecommendationFeedback, where: f.positive == true)
      |> Repo.aggregate(:count)

    negative = total - positive

    %{
      total: total,
      positive: positive,
      negative: negative,
      positive_rate: if(total > 0, do: Float.round(positive / total * 100, 1), else: 0.0)
    }
  end

  @spec counts_by_source() :: %{
          String.t() => %{positive: non_neg_integer(), negative: non_neg_integer()}
        }
  def counts_by_source do
    from(f in RecommendationFeedback,
      group_by: [f.source, f.positive],
      select: {f.source, f.positive, count(f.id)}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {source, positive, count}, acc ->
      key = if positive, do: :positive, else: :negative
      default = Map.put(%{positive: 0, negative: 0}, key, count)
      Map.update(acc, source, default, &Map.put(&1, key, count))
    end)
  end

  @spec top_games(boolean(), non_neg_integer()) :: [map()]
  def top_games(positive, limit \\ 10) do
    from(f in RecommendationFeedback,
      where: f.positive == ^positive,
      join: bg in assoc(f, :board_game),
      group_by: [bg.id, bg.name, bg.thumbnail_url],
      select: %{
        board_game_id: bg.id,
        name: bg.name,
        thumbnail_url: bg.thumbnail_url,
        count: count(f.id)
      },
      order_by: [desc: count(f.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  @spec recent_feedback(non_neg_integer()) :: [RecommendationFeedback.t()]
  def recent_feedback(limit \\ 20) do
    from(f in RecommendationFeedback,
      join: bg in assoc(f, :board_game),
      join: u in assoc(f, :user),
      preload: [board_game: bg, user: u],
      order_by: [desc: f.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end
end
