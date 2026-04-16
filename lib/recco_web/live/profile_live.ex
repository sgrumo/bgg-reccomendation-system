defmodule ReccoWeb.ProfileLive do
  use ReccoWeb, :live_view

  alias Recco.Accounts
  alias Recco.Accounts.User

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    password_form = User.password_changeset(user, %{}) |> to_form(as: "password")

    {:ok,
     assign(socket,
       page_title: gettext("Profile"),
       password_form: password_form,
       current_password_error: nil
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("validate_password", %{"password" => params}, socket) do
    form =
      socket.assigns.current_user
      |> User.password_changeset(params)
      |> Map.put(:action, :validate)
      |> to_form(as: "password")

    {:noreply, assign(socket, password_form: form, current_password_error: nil)}
  end

  def handle_event("change_password", %{"password" => params}, socket) do
    current_password = params["current_password"] || ""

    case Accounts.change_user_password(socket.assigns.current_user, current_password, params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Password changed successfully."))
         |> redirect(to: ~p"/profile")}

      {:error, :unauthorized} ->
        {:noreply, assign(socket, current_password_error: gettext("is incorrect"))}

      {:error, :unprocessable_entity, _errors} ->
        form =
          socket.assigns.current_user
          |> User.password_changeset(params)
          |> Map.put(:action, :validate)
          |> to_form(as: "password")

        {:noreply, assign(socket, password_form: form)}
    end
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="max-w-xl">
      <h1 class="text-2xl font-bold mb-6">{gettext("Profile")}</h1>

      <div class="rounded-base border-2 border-border bg-bw p-6 shadow-brutalist mb-6">
        <h2 class="text-lg font-bold mb-4">{gettext("Account details")}</h2>
        <dl class="space-y-3 text-sm">
          <div class="flex gap-2">
            <dt class="font-bold">{gettext("Username")}:</dt>
            <dd>{@current_user.username}</dd>
          </div>
          <div class="flex gap-2">
            <dt class="font-bold">{gettext("Email")}:</dt>
            <dd>{@current_user.email}</dd>
          </div>
        </dl>
      </div>

      <div class="rounded-base border-2 border-border bg-bw p-6 shadow-brutalist">
        <h2 class="text-lg font-bold mb-4">{gettext("Change password")}</h2>

        <.form for={@password_form} phx-change="validate_password" phx-submit="change_password" class="space-y-4">
          <div>
            <label for="password_current_password" class="block text-sm font-bold mb-1">
              {gettext("Current password")}
            </label>
            <input
              type="password"
              name="password[current_password]"
              id="password_current_password"
              required
              class={[
                "w-full rounded-base border-2 border-border bg-bw px-3 py-2 text-sm font-medium shadow-brutalist-sm focus:outline-none focus:ring-2 focus:ring-main",
                @current_password_error && "border-red-500"
              ]}
            />
            <p :if={@current_password_error} class="mt-1 text-xs text-red-500 font-medium">
              {@current_password_error}
            </p>
          </div>

          <.input field={@password_form[:password]} type="password" label={gettext("New password")} />

          <button
            type="submit"
            class="rounded-base border-2 border-border bg-main px-4 py-2.5 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            {gettext("Change password")}
          </button>
        </.form>
      </div>

      <div class="rounded-base border-2 border-border bg-bw p-6 shadow-brutalist mt-6">
        <h2 class="text-lg font-bold mb-4">{gettext("Session")}</h2>
        <.link
          href={~p"/logout"}
          method="delete"
          class="rounded-base border-2 border-border bg-bw px-4 py-2.5 text-sm font-bold hover:bg-red-300 transition-colors"
        >
          {gettext("Sign out")}
        </.link>
      </div>
    </div>
    """
  end
end
