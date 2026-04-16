defmodule ReccoWeb.ProfileLive do
  use ReccoWeb, :live_view

  require Logger

  alias Recco.Accounts
  alias Recco.Accounts.User
  alias Recco.Ratings

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    password_form = User.password_changeset(user, %{}) |> to_form(as: "password")
    bgg_form = User.bgg_username_changeset(user, %{}) |> to_form(as: "bgg")

    {:ok,
     assign(socket,
       page_title: gettext("Profile"),
       password_form: password_form,
       bgg_form: bgg_form,
       current_password_error: nil,
       import_status: nil
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("save_bgg_username", %{"bgg" => params}, socket) do
    case Accounts.update_bgg_username(socket.assigns.current_user, params) do
      {:ok, user} ->
        bgg_form = User.bgg_username_changeset(user, %{}) |> to_form(as: "bgg")

        {:noreply,
         socket
         |> assign(current_user: user, bgg_form: bgg_form)
         |> put_flash(:info, gettext("BGG username saved."))}

      {:error, :unprocessable_entity, _errors} ->
        form =
          socket.assigns.current_user
          |> User.bgg_username_changeset(params)
          |> Map.put(:action, :validate)
          |> to_form(as: "bgg")

        {:noreply, assign(socket, bgg_form: form)}
    end
  end

  def handle_event("import_bgg_ratings", _params, socket) do
    user = socket.assigns.current_user

    if user.bgg_username do
      user_id = user.id
      bgg_username = user.bgg_username

      socket = assign(socket, import_status: :loading)

      {:noreply,
       start_async(socket, :import_ratings, fn ->
         Ratings.import_bgg_ratings(user_id, bgg_username)
       end)}
    else
      {:noreply, put_flash(socket, :error, gettext("Set your BGG username first."))}
    end
  end

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
  def handle_async(:import_ratings, {:ok, {:ok, count}}, socket) do
    {:noreply,
     socket
     |> assign(import_status: {:done, count})
     |> put_flash(:info, gettext("Imported %{count} ratings from BGG.", count: count))}
  end

  def handle_async(:import_ratings, {:ok, {:error, reason}}, socket) do
    Logger.error("BGG import failed: #{inspect(reason)}")

    message =
      case reason do
        :timeout ->
          gettext("BGG is processing your collection. Please try again in a few seconds.")

        :rate_limited ->
          gettext("BGG rate limit reached. Please try again later.")

        _ ->
          gettext("Failed to import ratings from BGG.")
      end

    {:noreply,
     socket
     |> assign(import_status: :error)
     |> put_flash(:error, message)}
  end

  def handle_async(:import_ratings, {:exit, reason}, socket) do
    Logger.error("BGG import crashed: #{inspect(reason)}")

    {:noreply,
     socket
     |> assign(import_status: :error)
     |> put_flash(:error, gettext("Failed to import ratings from BGG."))}
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

      <div class="rounded-base border-2 border-border bg-bw p-6 shadow-brutalist mb-6">
        <h2 class="text-lg font-bold mb-4">{gettext("BoardGameGeek")}</h2>
        <p class="text-sm mb-4">
          {gettext("Link your BGG account to import your ratings automatically.")}
        </p>

        <.form for={@bgg_form} phx-submit="save_bgg_username" class="space-y-4">
          <.input field={@bgg_form[:bgg_username]} type="text" label={gettext("BGG username")} />

          <div class="flex gap-3">
            <button
              type="submit"
              class="rounded-base border-2 border-border bg-main px-4 py-2.5 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
            >
              {gettext("Save")}
            </button>
          </div>
        </.form>

        <div :if={@current_user.bgg_username} class="mt-4 pt-4 border-t-2 border-border">
          <p class="text-sm mb-3">
            {gettext(
              "Import your rated games from BGG. Games you've already rated here will be skipped."
            )}
          </p>
          <button
            phx-click="import_bgg_ratings"
            disabled={@import_status == :loading}
            class={[
              "rounded-base border-2 border-border px-4 py-2.5 text-sm font-bold shadow-brutalist transition-all",
              @import_status == :loading && "bg-gray-200 cursor-wait",
              @import_status != :loading &&
                "bg-bw hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none"
            ]}
          >
            <%= if @import_status == :loading do %>
              {gettext("Importing...")}
            <% else %>
              {gettext("Import ratings from BGG")}
            <% end %>
          </button>
        </div>
      </div>

      <div class="rounded-base border-2 border-border bg-bw p-6 shadow-brutalist mb-6">
        <h2 class="text-lg font-bold mb-4">{gettext("Change password")}</h2>

        <.form
          for={@password_form}
          phx-change="validate_password"
          phx-submit="change_password"
          class="space-y-4"
        >
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

      <div class="rounded-base border-2 border-border bg-bw p-6 shadow-brutalist">
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
