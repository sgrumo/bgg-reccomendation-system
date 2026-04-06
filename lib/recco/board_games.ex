defmodule Recco.BoardGames do
  import Ecto.Query

  alias Recco.BoardGames.BoardGame
  alias Recco.BoardGames.CrawlState
  alias Recco.Errors
  alias Recco.Repo

  @spec upsert_board_game(map()) :: {:ok, BoardGame.t()} | Errors.t(map())
  def upsert_board_game(attrs) do
    %BoardGame{}
    |> BoardGame.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :bgg_id, :inserted_at]},
      conflict_target: :bgg_id,
      returning: true
    )
    |> Errors.handle_changeset_error()
  end

  @spec get_board_game_by_bgg_id(integer()) :: {:ok, BoardGame.t()} | Errors.t()
  def get_board_game_by_bgg_id(bgg_id) do
    case Repo.one(from bg in BoardGame, where: bg.bgg_id == ^bgg_id) do
      nil -> {:error, :not_found}
      board_game -> {:ok, board_game}
    end
  end

  @spec get_crawl_state(String.t()) :: {:ok, CrawlState.t()} | Errors.t()
  def get_crawl_state(key) do
    case Repo.one(from cs in CrawlState, where: cs.key == ^key) do
      nil -> {:error, :not_found}
      crawl_state -> {:ok, crawl_state}
    end
  end

  @spec board_game_count() :: non_neg_integer()
  def board_game_count do
    Repo.aggregate(BoardGame, :count)
  end

  @spec max_bgg_id() :: non_neg_integer()
  def max_bgg_id do
    Repo.aggregate(BoardGame, :max, :bgg_id) || 0
  end

  @spec upsert_crawl_state(String.t(), map()) :: {:ok, CrawlState.t()} | Errors.t(map())
  def upsert_crawl_state(key, attrs) do
    %CrawlState{}
    |> CrawlState.changeset(Map.put(attrs, :key, key))
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :key, :inserted_at]},
      conflict_target: :key,
      returning: true
    )
    |> Errors.handle_changeset_error()
  end
end
