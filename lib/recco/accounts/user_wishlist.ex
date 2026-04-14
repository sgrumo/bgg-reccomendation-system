defmodule Recco.Accounts.UserWishlist do
  use Ecto.Schema

  import Ecto.Changeset

  alias Recco.Accounts.User
  alias Recco.BoardGames.BoardGame

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_wishlists" do
    belongs_to :user, User
    belongs_to :board_game, BoardGame

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(wishlist, attrs) do
    wishlist
    |> cast(attrs, [])
    |> unique_constraint([:user_id, :board_game_id])
  end
end
