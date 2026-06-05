defmodule Recco.Prototypes.Link do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :label, :string
    field :url, :string
  end

  @spec changeset(t() | map(), map()) :: Ecto.Changeset.t()
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:label, :url])
    |> validate_required([:label, :url])
    |> validate_length(:label, min: 1, max: 100)
    |> validate_length(:url, max: 2000)
    |> validate_format(:url, ~r{^https?://}i, message: "must start with http:// or https://")
  end
end
