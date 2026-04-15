defmodule Recco.Accounts.RecommendationFeedback do
  use Ecto.Schema

  import Ecto.Changeset

  alias Recco.Accounts.User
  alias Recco.BoardGames.BoardGame

  @type t :: %__MODULE__{}

  @sources ~w(user_recommendations similar_games)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "recommendation_feedback" do
    field :positive, :boolean
    field :source, :string

    belongs_to :user, User
    belongs_to :board_game, BoardGame

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [:positive, :source])
    |> validate_required([:positive, :source])
    |> validate_inclusion(:source, @sources)
    |> unique_constraint([:user_id, :board_game_id])
  end
end
