defmodule Recco.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias Recco.Accounts.{User, UserToken}
  alias Recco.Errors
  alias Recco.Repo

  @spec register_user(map()) :: {:ok, User.t()} | Errors.t(map())
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> Errors.handle_changeset_error()
  end

  @spec authenticate_user_by_email(String.t(), String.t()) :: {:ok, User.t()} | Errors.t()
  def authenticate_user_by_email(email, password) do
    user = Repo.get_by(User, email: email)

    if User.valid_password?(user, password) do
      {:ok, user}
    else
      {:error, :unauthorized}
    end
  end

  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @spec get_user_by_id(String.t()) :: User.t() | nil
  def get_user_by_id(id) when is_binary(id) do
    Repo.get(User, id)
  end

  @spec generate_user_session_token(User.t()) :: binary()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @spec get_user_by_session_token(binary()) :: User.t() | nil
  def get_user_by_session_token(token) do
    UserToken.verify_session_token_query(token)
    |> Repo.one()
  end

  @spec delete_user_session_token(binary()) :: :ok
  def delete_user_session_token(token) do
    UserToken
    |> Repo.get_by(token: token, context: "session")
    |> case do
      nil -> :ok
      token_record -> Repo.delete!(token_record)
    end

    :ok
  end

  @spec superadmin?(User.t()) :: boolean()
  def superadmin?(user), do: User.superadmin?(user)
end
