defmodule Recco.Prototypes.PrototypeImage do
  use Ecto.Schema

  import Ecto.Changeset

  alias Recco.Prototypes.Prototype

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "prototype_images" do
    field :path, :string
    field :original_filename, :string
    field :position, :integer, default: 0

    belongs_to :prototype, Prototype

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(image, attrs) do
    image
    |> cast(attrs, [:path, :original_filename, :position])
    |> validate_required([:path, :original_filename, :position])
    |> validate_number(:position, greater_than_or_equal_to: 0)
  end
end
