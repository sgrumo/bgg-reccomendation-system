defmodule Recco.Accounts.UserToken do
  use Ecto.Schema

  import Ecto.Query

  @type t :: %__MODULE__{}

  @rand_size 32
  @session_validity_in_days 60
  @reset_password_validity_in_hours 1

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

  @spec build_reset_password_token(Recco.Accounts.User.t()) :: {binary(), t()}
  def build_reset_password_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)

    {Base.url_encode64(token, padding: false),
     %__MODULE__{
       token: token,
       context: "reset_password",
       user_id: user.id
     }}
  end

  @spec verify_reset_password_token_query(binary()) :: Ecto.Query.t()
  def verify_reset_password_token_query(encoded_token) do
    case Base.url_decode64(encoded_token, padding: false) do
      {:ok, token} ->
        from token_record in __MODULE__,
          join: user in assoc(token_record, :user),
          where: token_record.token == ^token,
          where: token_record.context == "reset_password",
          where: token_record.inserted_at > ago(@reset_password_validity_in_hours, "hour"),
          select: user

      :error ->
        from u in Recco.Accounts.User, where: false
    end
  end
end
