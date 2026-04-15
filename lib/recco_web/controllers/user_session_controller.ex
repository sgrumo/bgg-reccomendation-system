defmodule ReccoWeb.UserSessionController do
  use ReccoWeb, :html_controller

  alias Recco.Accounts

  plug :put_layout, html: {ReccoWeb.Layouts, :public}

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user_by_email(email, password) do
      {:ok, user} ->
        token = Accounts.generate_user_session_token(user)

        conn
        |> renew_session()
        |> put_session(:user_token, token)
        |> put_flash(:info, gettext("Welcome back!"))
        |> redirect(to: ~p"/")

      {:error, :unauthorized} ->
        render(conn, :new, error_message: gettext("Invalid email or password"))
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, _params) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    conn
    |> renew_session()
    |> put_flash(:info, gettext("Logged out successfully."))
    |> redirect(to: ~p"/")
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
