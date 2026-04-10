defmodule ReccoWeb.PreferenceLive.Edit do
  use ReccoWeb, :live_view

  alias Recco.Accounts.UserPreference
  alias Recco.Preferences

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    preference =
      Preferences.get_preferences(socket.assigns.current_user.id) ||
        %UserPreference{user_id: socket.assigns.current_user.id}

    form = preference |> UserPreference.changeset(%{}) |> to_form()

    {:ok,
     assign(socket,
       page_title: "Preferences",
       preference: preference,
       form: form
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("validate", %{"user_preference" => params}, socket) do
    form =
      socket.assigns.preference
      |> UserPreference.changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"user_preference" => params}, socket) do
    case Preferences.upsert_preferences(socket.assigns.current_user.id, params) do
      {:ok, preference} ->
        form = preference |> UserPreference.changeset(%{}) |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Preferences saved!")
         |> assign(preference: preference, form: form)}

      {:error, :unprocessable_entity, _errors} ->
        form =
          socket.assigns.preference
          |> UserPreference.changeset(params)
          |> Map.put(:action, :insert)
          |> to_form()

        {:noreply, assign(socket, form: form)}
    end
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="max-w-xl">
      <h1 class="text-2xl font-bold text-zinc-900 mb-6">Preferences</h1>
      <p class="text-sm text-zinc-500 mb-6">
        Set your preferences to improve recommendations.
      </p>

      <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:min_players]} type="number" label="Min players" />
          <.input field={@form[:max_players]} type="number" label="Max players" />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:min_weight]} type="number" label="Min weight" step="0.1" />
          <.input field={@form[:max_weight]} type="number" label="Max weight" step="0.1" />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:min_playtime]} type="number" label="Min playtime (min)" />
          <.input field={@form[:max_playtime]} type="number" label="Max playtime (min)" />
        </div>

        <button
          type="submit"
          class="rounded-lg bg-brand-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-brand-500"
        >
          Save preferences
        </button>
      </.form>
    </div>
    """
  end
end
