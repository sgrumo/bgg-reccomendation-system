defmodule Recco.Accounts.UserPreference do
  use Ecto.Schema

  import Ecto.Changeset

  alias Recco.Accounts.User

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_preferences" do
    field :preferred_categories, {:array, :string}, default: []
    field :preferred_mechanics, {:array, :string}, default: []
    field :min_players, :integer
    field :max_players, :integer
    field :min_weight, :float
    field :max_weight, :float
    field :min_playtime, :integer
    field :max_playtime, :integer

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [
      :preferred_categories,
      :preferred_mechanics,
      :min_players,
      :max_players,
      :min_weight,
      :max_weight,
      :min_playtime,
      :max_playtime
    ])
    |> validate_number(:min_players, greater_than: 0)
    |> validate_number(:max_players, greater_than: 0)
    |> validate_number(:min_weight, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 5.0)
    |> validate_number(:max_weight, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 5.0)
    |> validate_number(:min_playtime, greater_than: 0)
    |> validate_number(:max_playtime, greater_than: 0)
    |> unique_constraint(:user_id)
  end
end
