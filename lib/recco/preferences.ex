defmodule Recco.Preferences do
  @moduledoc """
  The Preferences context.
  """

  alias Recco.Accounts.UserPreference
  alias Recco.Errors
  alias Recco.Repo

  @spec get_preferences(String.t()) :: UserPreference.t() | nil
  def get_preferences(user_id) do
    Repo.get_by(UserPreference, user_id: user_id)
  end

  @spec upsert_preferences(String.t(), map()) :: {:ok, UserPreference.t()} | Errors.t(map())
  def upsert_preferences(user_id, attrs) do
    case Repo.get_by(UserPreference, user_id: user_id) do
      nil -> %UserPreference{user_id: user_id}
      existing -> existing
    end
    |> UserPreference.changeset(attrs)
    |> Repo.insert_or_update()
    |> Errors.handle_changeset_error()
  end
end
