defmodule ReccoWeb.ResetPasswordLive do
  use ReccoWeb, :live_view

  alias Recco.Accounts
  alias Recco.Accounts.User

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:ok, Phoenix.LiveView.Socket.t(), keyword()}
  def mount(%{"token" => token}, _session, socket) do
    socket = assign(socket, page_title: gettext("Reset password"))

    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Reset password link is invalid or it has expired."))
         |> redirect(to: ~p"/login")}

      user ->
        changeset = User.password_changeset(user, %{})

        {:ok, assign(socket, user: user, form: to_form(changeset), token: token),
         temporary_assigns: [form: nil]}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> User.password_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("reset", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Password reset successfully."))
         |> redirect(to: ~p"/login")}

      {:error, :unprocessable_entity, _errors} ->
        changeset =
          socket.assigns.user
          |> User.password_changeset(user_params)
          |> Map.put(:action, :validate)

        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md mt-16 px-4">
      <div class="panel panel-lg p-8">
        <div class="label mb-2">{gettext("Almost there")}</div>
        <h1 class="text-[clamp(30px,3.6vw,44px)] mb-7">{gettext("Reset password")}</h1>

        <.form for={@form} phx-submit="reset" phx-change="validate">
          <div class="space-y-4">
            <.input
              field={@form[:password]}
              type="password"
              label={gettext("New password")}
              required
            />
          </div>

          <button type="submit" class="btn btn-primary btn-lg w-full justify-center mt-6">
            {gettext("Reset password")} →
          </button>
        </.form>

        <p class="mt-6 text-center text-sm">
          <a href={~p"/login"} class="font-bold underline decoration-2 underline-offset-2">
            {gettext("Back to sign in")}
          </a>
        </p>
      </div>
    </div>
    """
  end
end
