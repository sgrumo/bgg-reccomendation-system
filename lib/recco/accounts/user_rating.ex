defmodule Recco.Accounts.UserRating do
  use Ecto.Schema

  import Ecto.Changeset

  alias Recco.Accounts.User
  alias Recco.BoardGames.BoardGame

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_ratings" do
    field :score, :float
    field :comment, :string

    belongs_to :user, User
    belongs_to :board_game, BoardGame

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(rating, attrs) do
    rating
    |> cast(attrs, [:score, :comment])
    |> validate_required([:score])
    |> validate_number(:score, greater_than_or_equal_to: 1.0, less_than_or_equal_to: 10.0)
    |> unique_constraint([:user_id, :board_game_id])
  end
end
