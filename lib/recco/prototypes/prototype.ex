defmodule Recco.Prototypes.Prototype do
  use Ecto.Schema

  import Ecto.Changeset

  alias Recco.Accounts.User
  alias Recco.Prototypes.Collaborator
  alias Recco.Prototypes.Link
  alias Recco.Prototypes.PrototypeImage

  @type t :: %__MODULE__{}

  @castable_fields [
    :title,
    :description,
    :min_players,
    :max_players,
    :min_playtime,
    :max_playtime,
    :categories,
    :mechanics,
    :contact_email
  ]

  @required_fields [
    :title,
    :description,
    :min_players,
    :max_players,
    :min_playtime,
    :max_playtime,
    :contact_email
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "prototypes" do
    field :title, :string
    field :description, :string
    field :min_players, :integer
    field :max_players, :integer
    field :min_playtime, :integer
    field :max_playtime, :integer
    field :categories, {:array, :string}, default: []
    field :mechanics, {:array, :string}, default: []
    field :contact_email, :string
    field :blocked_at, :utc_datetime

    embeds_many :collaborators, Collaborator, on_replace: :delete
    embeds_many :links, Link, on_replace: :delete

    belongs_to :user, User
    has_many :images, PrototypeImage, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(prototype, attrs) do
    prototype
    |> cast(attrs, @castable_fields)
    |> cast_embed(:collaborators, with: &Collaborator.changeset/2, required: true)
    |> cast_embed(:links, with: &Link.changeset/2)
    |> validate_required(@required_fields)
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:description, min: 1, max: 5000)
    |> validate_format(:contact_email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      message: "must be a valid email"
    )
    |> validate_length(:contact_email, max: 160)
    |> validate_number(:min_players, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:max_players, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:min_playtime, greater_than: 0, less_than_or_equal_to: 100_000)
    |> validate_number(:max_playtime, greater_than: 0, less_than_or_equal_to: 100_000)
    |> validate_range(:min_players, :max_players, "must be greater than or equal to min players")
    |> validate_range(
      :min_playtime,
      :max_playtime,
      "must be greater than or equal to min playtime"
    )
    |> validate_non_empty_list(:categories)
    |> validate_non_empty_list(:mechanics)
    |> validate_length(:categories, max: 20)
    |> validate_length(:mechanics, max: 30)
  end

  defp validate_range(changeset, min_field, max_field, message) do
    min = get_field(changeset, min_field)
    max = get_field(changeset, max_field)

    if is_integer(min) and is_integer(max) and min > max do
      add_error(changeset, max_field, message)
    else
      changeset
    end
  end

  defp validate_non_empty_list(changeset, field) do
    case get_field(changeset, field) do
      list when is_list(list) and list != [] -> changeset
      _ -> add_error(changeset, field, "can't be empty")
    end
  end
end
