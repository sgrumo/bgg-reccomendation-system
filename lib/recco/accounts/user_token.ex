defmodule Recco.Accounts.UserToken do
  use Ecto.Schema

  import Ecto.Query

  @type t :: %__MODULE__{}

  @rand_size 32
  @session_validity_in_days 60

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_tokens" do
    field :token, :binary
    field :context, :string

    belongs_to :user, Recco.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @spec build_session_token(Recco.Accounts.User.t()) :: {binary(), t()}
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)

    {token,
     %__MODULE__{
       token: token,
       context: "session",
       user_id: user.id
     }}
  end

  @spec verify_session_token_query(binary()) :: Ecto.Query.t()
  def verify_session_token_query(token) do
    from token_record in __MODULE__,
      join: user in assoc(token_record, :user),
      where: token_record.token == ^token,
      where: token_record.context == "session",
      where: token_record.inserted_at > ago(@session_validity_in_days, "day"),
      select: user
  end
end
