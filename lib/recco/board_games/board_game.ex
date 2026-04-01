defmodule Recco.BoardGames.BoardGame do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "board_games" do
    field :bgg_id, :integer
    field :name, :string
    field :alternate_names, {:array, :string}, default: []
    field :description, :string
    field :year_published, :integer
    field :min_players, :integer
    field :max_players, :integer
    field :min_playtime, :integer
    field :max_playtime, :integer
    field :playing_time, :integer
    field :min_age, :integer
    field :image_url, :string
    field :thumbnail_url, :string
    field :average_rating, :float
    field :bayes_average_rating, :float
    field :users_rated, :integer
    field :average_weight, :float
    field :categories, {:array, :map}, default: []
    field :mechanics, {:array, :map}, default: []
    field :designers, {:array, :map}, default: []
    field :artists, {:array, :map}, default: []
    field :publishers, {:array, :map}, default: []
    field :families, {:array, :map}, default: []
    field :ranks, {:array, :map}, default: []

    timestamps(type: :utc_datetime)
  end

  @castable_fields [
    :bgg_id,
    :name,
    :alternate_names,
    :description,
    :year_published,
    :min_players,
    :max_players,
    :min_playtime,
    :max_playtime,
    :playing_time,
    :min_age,
    :image_url,
    :thumbnail_url,
    :average_rating,
    :bayes_average_rating,
    :users_rated,
    :average_weight,
    :categories,
    :mechanics,
    :designers,
    :artists,
    :publishers,
    :families,
    :ranks
  ]

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(board_game, attrs) do
    board_game
    |> cast(attrs, @castable_fields)
    |> validate_required([:bgg_id])
    |> unique_constraint(:bgg_id)
  end
end
