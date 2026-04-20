defmodule Recco.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Recco.Accounts.{RateLimit, User, UserNotifier, UserPreference, UserToken, UserWishlist}
  alias Recco.Errors
  alias Recco.Repo

  @spec register_user(map()) :: {:ok, User.t()} | Errors.t(map())
  def register_user(attrs) do
    :telemetry.span([:recco, :auth, :register], %{}, fn ->
      result =
        %User{}
        |> User.registration_changeset(attrs)
        |> Repo.insert()
        |> Errors.handle_changeset_error()

      {result, %{result: register_result_tag(result)}}
    end)
  end

  defp register_result_tag({:ok, _}), do: :ok
  defp register_result_tag({:error, _, _}), do: :invalid

  @spec authenticate_user_by_email(String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :unauthorized} | {:error, :locked_out, non_neg_integer()}
  def authenticate_user_by_email(email, password) do
    :telemetry.span([:recco, :auth, :login], %{}, fn ->
      result = do_authenticate_user_by_email(email, password)
      {result, %{result: login_result_tag(result), email_hash: hash_email(email)}}
    end)
  end

  defp do_authenticate_user_by_email(email, password) do
    key = normalize_email(email)

    case RateLimit.peek(:login_account, key) do
      {:deny, retry_ms} ->
        {:error, :locked_out, div(retry_ms, 1000) + 1}

      :allow ->
        user = Repo.one(from u in active_users(), where: u.email == ^email)

        valid? =
          :telemetry.span([:recco, :auth, :bcrypt], %{path: bcrypt_path(user)}, fn ->
            result = User.valid_password?(user, password)
            {result, %{path: bcrypt_path(user)}}
          end)

        if valid? do
          RateLimit.clear(:login_account, key)
          {:ok, user}
        else
          RateLimit.record_failure(:login_account, key)
          {:error, :unauthorized}
        end
    end
  end

  defp bcrypt_path(nil), do: :no_user_verify
  defp bcrypt_path(%User{}), do: :verify

  defp login_result_tag({:ok, _}), do: :ok
  defp login_result_tag({:error, :unauthorized}), do: :invalid_credentials
  defp login_result_tag({:error, :locked_out, _}), do: :locked_out

  defp hash_email(email) when is_binary(email) do
    :crypto.hash(:sha256, String.downcase(String.trim(email)))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end

  defp hash_email(_), do: ""

  defp normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  defp normalize_email(_), do: ""

  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.one(from u in active_users(), where: u.email == ^email)
  end

  @spec get_user_by_id(String.t()) :: User.t() | nil
  def get_user_by_id(id) when is_binary(id) do
    Repo.one(from u in active_users(), where: u.id == ^id)
  end

  @doc """
  Admin-only lookup that includes soft-deleted users, so the admin UI
  can render their tombstone row and offer a restore action within the
  undelete window.
  """
  @spec admin_get_user_by_id(String.t()) :: User.t() | nil
  def admin_get_user_by_id(id) when is_binary(id), do: Repo.get(User, id)

  defp active_users, do: from(u in User, where: is_nil(u.deleted_at))

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

  @doc """
  Default delete is the soft path — it anonymizes PII, wipes tokens +
  preferences + wishlists, and keeps ratings/feedback for their
  statistical value. Use `hard_delete_user/1` for full removal.
  """
  @spec delete_user(User.t()) :: {:ok, User.t()} | Errors.t()
  def delete_user(user), do: soft_delete_user(user)

  @undelete_window_seconds 30 * 24 * 60 * 60
  @deleted_email_host "invalid.local"

  @spec soft_delete_user(User.t()) :: {:ok, User.t()} | Errors.t()
  def soft_delete_user(%User{role: "superadmin"}), do: {:error, :forbidden}

  def soft_delete_user(%User{deleted_at: %DateTime{}}), do: {:error, :already_deleted}

  def soft_delete_user(%User{} = user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    tombstone_attrs = %{
      deleted_at: now,
      email: "deleted-#{Ecto.UUID.generate()}@#{@deleted_email_host}",
      username: "deleted_#{short_id()}",
      hashed_password: random_unverifiable_hash(),
      bgg_username: nil
    }

    changeset =
      user
      |> Changeset.change(tombstone_attrs)
      |> Changeset.unique_constraint(:email)
      |> Changeset.unique_constraint(:username)

    Multi.new()
    |> Multi.update(:user, changeset)
    |> Multi.delete_all(:tokens, from(t in UserToken, where: t.user_id == ^user.id))
    |> Multi.delete_all(:prefs, from(p in UserPreference, where: p.user_id == ^user.id))
    |> Multi.delete_all(:wishlists, from(w in UserWishlist, where: w.user_id == ^user.id))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> Errors.handle_changeset_error({:error, changeset})
    end
  end

  @spec restore_user(User.t()) :: {:ok, User.t()} | {:error, :not_deleted | :window_expired}
  def restore_user(%User{deleted_at: nil}), do: {:error, :not_deleted}

  def restore_user(%User{deleted_at: deleted_at} = user) do
    seconds_since = DateTime.diff(DateTime.utc_now(), deleted_at)

    if seconds_since > @undelete_window_seconds do
      {:error, :window_expired}
    else
      user
      |> Changeset.change(deleted_at: nil)
      |> Repo.update()
      |> case do
        {:ok, user} -> {:ok, user}
        {:error, _} -> {:error, :window_expired}
      end
    end
  end

  @spec hard_delete_user(User.t()) :: {:ok, User.t()} | Errors.t()
  def hard_delete_user(%User{role: "superadmin"}), do: {:error, :forbidden}

  def hard_delete_user(%User{} = user) do
    Repo.delete(user) |> Errors.handle_changeset_error()
  end

  @spec mark_onboarded(User.t()) :: {:ok, User.t()} | Errors.t()
  def mark_onboarded(%User{onboarded_at: %DateTime{}} = user), do: {:ok, user}

  def mark_onboarded(%User{} = user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    user
    |> Changeset.change(onboarded_at: now)
    |> Repo.update()
    |> Errors.handle_changeset_error()
  end

  defp short_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end

  defp random_unverifiable_hash do
    # Long random string that can't match any real bcrypt output; prevents
    # any accidental future login attempt with an old password from
    # succeeding in a way the original owner could exploit.
    "$2b$04$" <> Base.encode16(:crypto.strong_rand_bytes(22), case: :lower)
  end

  @spec count_users() :: non_neg_integer()
  def count_users do
    Repo.aggregate(active_users(), :count)
  end

  @type list_users_opts :: %{
          optional(:search) => String.t(),
          optional(:page) => pos_integer(),
          optional(:per_page) => pos_integer(),
          optional(:include_deleted) => boolean()
        }

  @spec list_users(list_users_opts()) :: %{users: [map()], total: non_neg_integer()}
  def list_users(opts \\ %{}) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 20)

    base_query =
      if Map.get(opts, :include_deleted, false) do
        from(u in User, order_by: [desc: u.inserted_at])
      else
        from(u in active_users(), order_by: [desc: u.inserted_at])
      end

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
