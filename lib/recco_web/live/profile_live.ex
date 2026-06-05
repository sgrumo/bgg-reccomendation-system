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
    <div class="max-w-2xl pb-12">
      <div class="label mb-2">{gettext("Settings")}</div>
      <h1 class="text-[clamp(34px,4vw,58px)] mb-7">{gettext("Profile")}</h1>

      <div class="panel p-6 mb-5">
        <h2 class="text-2xl mb-4">{gettext("Account details")}</h2>
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

      <div class="panel p-6 mb-5">
        <h2 class="text-2xl mb-3">{gettext("BoardGameGeek")}</h2>
        <p class="text-ink-soft mb-4">
          {gettext("Link your BGG account to import your ratings automatically.")}
        </p>

        <.form for={@bgg_form} phx-submit="save_bgg_username" class="space-y-4">
          <.input field={@bgg_form[:bgg_username]} type="text" label={gettext("BGG username")} />

          <div class="flex gap-3">
            <button type="submit" class="btn btn-primary">{gettext("Save")}</button>
          </div>
        </.form>

        <div :if={@current_user.bgg_username} class="mt-5 pt-5 border-t-bw border-line">
          <p class="text-ink-soft mb-3">
            {gettext(
              "Import your rated games from BGG. Games you've already rated here will be skipped."
            )}
          </p>
          <button
            type="button"
            phx-click="import_bgg_ratings"
            disabled={@import_status == :loading}
            class={[
              "btn",
              @import_status == :loading && "cursor-wait"
            ]}
          >
            <%= if @import_status == :loading do %>
              {gettext("Importing…")}
            <% else %>
              {gettext("Import ratings from BGG")}
            <% end %>
          </button>
        </div>
      </div>

      <div class="panel p-6 mb-5">
        <h2 class="text-2xl mb-4">{gettext("Change password")}</h2>

        <.form
          for={@password_form}
          phx-change="validate_password"
          phx-submit="change_password"
          class="space-y-4"
        >
          <div>
            <label
              for="password_current_password"
              class="label label-ink !font-bold block mb-2"
            >
              {gettext("Current password")}
            </label>
            <input
              type="password"
              name="password[current_password]"
              id="password_current_password"
              required
              class={["field", @current_password_error && "!border-danger"]}
            />
            <p :if={@current_password_error} class="mt-1.5 text-sm font-semibold text-danger">
              {@current_password_error}
            </p>
          </div>

          <.input field={@password_form[:password]} type="password" label={gettext("New password")} />

          <button type="submit" class="btn btn-primary">{gettext("Change password")}</button>
        </.form>
      </div>

      <div class="panel p-6">
        <h2 class="text-2xl mb-4">{gettext("Session")}</h2>
        <.link
          href={~p"/logout"}
          method="delete"
          class="btn hover:!bg-danger hover:!text-accent-ink"
        >
          {gettext("Sign out")}
        </.link>
      </div>
    </div>
    """
  end
end
