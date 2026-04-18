defmodule Recco.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Recco.Accounts.{RateLimit, User, UserNotifier, UserToken}
  alias Recco.Errors
  alias Recco.Repo

  @spec register_user(map()) :: {:ok, User.t()} | Errors.t(map())
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> Errors.handle_changeset_error()
  end

  @spec authenticate_user_by_email(String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :unauthorized} | {:error, :locked_out, non_neg_integer()}
  def authenticate_user_by_email(email, password) do
    key = normalize_email(email)

    case RateLimit.peek(:login_account, key) do
      {:deny, retry_ms} ->
        {:error, :locked_out, div(retry_ms, 1000) + 1}

      :allow ->
        user = Repo.get_by(User, email: email)

        if User.valid_password?(user, password) do
          RateLimit.clear(:login_account, key)
          {:ok, user}
        else
          RateLimit.record_failure(:login_account, key)
          {:error, :unauthorized}
        end
    end
  end

  defp normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  defp normalize_email(_), do: ""

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

  @spec deliver_reset_password_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_reset_password_instructions(%User{} = user, reset_url_fn)
      when is_function(reset_url_fn, 1) do
    {encoded_token, user_token} = UserToken.build_reset_password_token(user)
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_url_fn.(encoded_token))
  end

  @spec get_user_by_reset_password_token(String.t()) :: User.t() | nil
  def get_user_by_reset_password_token(token) do
    UserToken.verify_reset_password_token_query(token)
    |> Repo.one()
  end

  @spec reset_user_password(User.t(), map()) :: {:ok, User.t()} | Errors.t(map())
  def reset_user_password(%User{} = user, attrs) do
    Multi.new()
    |> Multi.update(:user, User.password_changeset(user, attrs))
    |> Multi.delete_all(:tokens, from(t in UserToken, where: t.user_id == ^user.id))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> Errors.handle_changeset_error({:error, changeset})
    end
  end

  @spec update_bgg_username(User.t(), map()) :: {:ok, User.t()} | Errors.t(map())
  def update_bgg_username(%User{} = user, attrs) do
    user
    |> User.bgg_username_changeset(attrs)
    |> Repo.update()
    |> Errors.handle_changeset_error()
  end

  @spec change_user_password(User.t(), String.t(), map()) ::
          {:ok, User.t()} | Errors.t() | Errors.t(map())
  def change_user_password(%User{} = user, current_password, attrs) do
    if User.valid_password?(user, current_password) do
      user
      |> User.password_changeset(attrs)
      |> Repo.update()
      |> Errors.handle_changeset_error()
    else
      {:error, :unauthorized}
    end
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
