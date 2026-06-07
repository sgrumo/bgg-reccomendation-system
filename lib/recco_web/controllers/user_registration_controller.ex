defmodule ReccoWeb.UserRegistrationController do
  use ReccoWeb, :html_controller

  require Logger

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
        user
        |> Accounts.deliver_confirmation_instructions(fn token -> url(~p"/confirm/#{token}") end)
        |> log_delivery_failure(flow: :confirmation, user_id: user.id)

        token = Accounts.generate_user_session_token(user)

        conn
        |> put_session(:user_token, token)
        |> put_flash(:info, gettext("Account created successfully!"))
        |> redirect(to: ~p"/onboarding")

      {:error, :unprocessable_entity, _errors} ->
        changeset =
          %User{}
          |> User.registration_changeset(user_params)
          |> Map.put(:action, :insert)

        render(conn, :new, form: Phoenix.Component.to_form(changeset))
    end
  end

  defp log_delivery_failure({:ok, _}, _meta), do: :ok
  defp log_delivery_failure({:error, :already_confirmed}, _meta), do: :ok

  defp log_delivery_failure({:error, reason}, meta) do
    Logger.warning(
      "Email delivery failed",
      Keyword.put(meta, :reason, inspect(reason))
    )
  end
end
