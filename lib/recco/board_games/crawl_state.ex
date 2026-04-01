defmodule Recco.BoardGames.CrawlState do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "crawl_state" do
    field :key, :string
    field :last_fetched_id, :integer, default: 0
    field :status, :string, default: "idle"
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(crawl_state, attrs) do
    crawl_state
    |> cast(attrs, [:key, :last_fetched_id, :status, :metadata])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
