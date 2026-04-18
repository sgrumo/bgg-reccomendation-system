defmodule ReccoWeb.UserRegistrationController do
  use ReccoWeb, :html_controller

  alias Recco.Accounts
  alias Recco.Accounts.User

  plug :put_layout, html: {ReccoWeb.Layouts, :public}
  plug ReccoWeb.Plugs.RateLimit, [scope: :register_ip] when action == :create

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = User.registration_changeset(%User{}, %{})
    render(conn, :new, form: Phoenix.Component.to_form(changeset))
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        token = Accounts.generate_user_session_token(user)

        conn
        |> put_session(:user_token, token)
        |> put_flash(:info, gettext("Account created successfully!"))
        |> redirect(to: ~p"/")

      {:error, :unprocessable_entity, _errors} ->
        changeset =
          %User{}
          |> User.registration_changeset(user_params)
          |> Map.put(:action, :insert)

        render(conn, :new, form: Phoenix.Component.to_form(changeset))
    end
  end
end
