defmodule Recco.Prototypes.PrototypeLike do
  use Ecto.Schema

  import Ecto.Changeset

  alias Recco.Accounts.User
  alias Recco.Prototypes.Prototype

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "prototype_likes" do
    belongs_to :user, User
    belongs_to :prototype, Prototype

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(like, attrs) do
    like
    |> cast(attrs, [])
    |> unique_constraint([:user_id, :prototype_id])
  end
end
