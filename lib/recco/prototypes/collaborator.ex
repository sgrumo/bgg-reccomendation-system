defmodule Recco.Prototypes.Collaborator do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :name, :string
    field :role, :string
  end

  @spec changeset(t() | map(), map()) :: Ecto.Changeset.t()
  def changeset(collaborator, attrs) do
    collaborator
    |> cast(attrs, [:name, :role])
    |> validate_required([:name, :role])
    |> validate_length(:name, min: 1, max: 200)
    |> validate_length(:role, min: 1, max: 100)
  end
end
