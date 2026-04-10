defmodule ReccoWeb.Plugs.FetchCurrentUser do
  @moduledoc """
  Reads the session token and assigns :current_user for browser requests.
  """

  import Plug.Conn

  alias Recco.Accounts

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    token = get_session(conn, :user_token)
    user = token && Accounts.get_user_by_session_token(token)

    assign(conn, :current_user, user)
  end
end
