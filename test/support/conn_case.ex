defmodule ReccoWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint ReccoWeb.Endpoint

      use ReccoWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import ReccoWeb.ConnCase
      import Recco.Factory
    end
  end

  setup tags do
    Recco.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Adds a valid Bearer token to the connection for authenticated API tests.
  """
  @spec authenticate(Plug.Conn.t()) :: Plug.Conn.t()
  def authenticate(conn) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer valid_token")
  end

  @doc """
  Adds a superadmin Bearer token to the connection.
  """
  @spec authenticate_superadmin(Plug.Conn.t()) :: Plug.Conn.t()
  def authenticate_superadmin(conn) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer valid_superadmin_token")
  end

  @doc """
  Logs in a user via session for browser/LiveView tests.
  """
  @spec log_in_user(Plug.Conn.t(), Recco.Accounts.User.t()) :: Plug.Conn.t()
  def log_in_user(conn, user) do
    token = Recco.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
