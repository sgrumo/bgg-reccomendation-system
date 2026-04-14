defmodule Recco.Wishlists do
  @moduledoc """
  The Wishlists context.
  """

  import Ecto.Query

  alias Recco.Accounts.UserWishlist
  alias Recco.Errors
  alias Recco.Repo

  @spec add_to_wishlist(String.t(), String.t()) :: {:ok, UserWishlist.t()} | Errors.t(map())
  def add_to_wishlist(user_id, board_game_id) do
    %UserWishlist{user_id: user_id, board_game_id: board_game_id}
    |> UserWishlist.changeset(%{})
    |> Repo.insert()
    |> Errors.handle_changeset_error()
  end

  @spec remove_from_wishlist(String.t(), String.t()) :: :ok | Errors.t()
  def remove_from_wishlist(user_id, board_game_id) do
    case Repo.get_by(UserWishlist, user_id: user_id, board_game_id: board_game_id) do
      nil ->
        {:error, :not_found}

      wishlist ->
        Repo.delete!(wishlist)
        :ok
    end
  end

  @spec wishlisted?(String.t(), String.t()) :: boolean()
  def wishlisted?(user_id, board_game_id) do
    from(w in UserWishlist,
      where: w.user_id == ^user_id and w.board_game_id == ^board_game_id
    )
    |> Repo.exists?()
  end

  @spec list_user_wishlists(String.t()) :: [UserWishlist.t()]
  def list_user_wishlists(user_id) do
    from(w in UserWishlist,
      where: w.user_id == ^user_id,
      join: bg in assoc(w, :board_game),
      preload: [board_game: bg],
      order_by: [desc: w.inserted_at]
    )
    |> Repo.all()
  end

  @spec count_user_wishlists(String.t()) :: non_neg_integer()
  def count_user_wishlists(user_id) do
    from(w in UserWishlist, where: w.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  @spec total_wishlists_count() :: non_neg_integer()
  def total_wishlists_count do
    Repo.aggregate(UserWishlist, :count)
  end
end
