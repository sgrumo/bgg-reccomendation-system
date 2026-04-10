defmodule Recco.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query

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

  @spec delete_user(User.t()) :: {:ok, User.t()} | Errors.t()
  def delete_user(%User{role: "superadmin"}), do: {:error, :forbidden}

  def delete_user(%User{} = user) do
    Repo.delete(user)
    |> Errors.handle_changeset_error()
  end

  @spec count_users() :: non_neg_integer()
  def count_users do
    Repo.aggregate(User, :count)
  end

  @type list_users_opts :: %{
          optional(:search) => String.t(),
          optional(:page) => pos_integer(),
          optional(:per_page) => pos_integer()
        }

  @spec list_users(list_users_opts()) :: %{users: [map()], total: non_neg_integer()}
  def list_users(opts \\ %{}) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 20)

    base_query = from(u in User, order_by: [desc: u.inserted_at])

    base_query =
      case opts do
        %{search: search} when is_binary(search) and search != "" ->
          term = "%#{search}%"
          from u in base_query, where: ilike(u.email, ^term) or ilike(u.username, ^term)

        _ ->
          base_query
      end

    total = Repo.aggregate(base_query, :count)

    rating_counts =
      from(r in Recco.Accounts.UserRating,
        group_by: r.user_id,
        select: %{user_id: r.user_id, count: count(r.id)}
      )

    rows =
      from(u in base_query,
        left_join: rc in subquery(rating_counts),
        on: rc.user_id == u.id,
        select: %{user: u, rating_count: coalesce(rc.count, 0)}
      )
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{users: rows, total: total}
  end
end
