defmodule Recco.BoardGames.Mechanic do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "mechanics" do
    field :bgg_id, :integer
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(mechanic, attrs) do
    mechanic
    |> cast(attrs, [:bgg_id, :name])
    |> validate_required([:bgg_id, :name])
    |> unique_constraint(:bgg_id)
    |> unique_constraint(:name)
  end
end
