defmodule ReccoWeb.PrototypeLive.Show do
  use ReccoWeb, :live_view

  alias Recco.Accounts
  alias Recco.Prototypes

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    case Prototypes.get_prototype(id) do
      {:ok, prototype} ->
        owner? = Prototypes.owns?(prototype, user)
        admin? = Accounts.superadmin?(user)

        if Prototypes.blocked?(prototype) and not (owner? or admin?) do
          {:ok,
           socket
           |> put_flash(:error, gettext("Prototype not found"))
           |> redirect(to: ~p"/prototypes")}
        else
          {:ok,
           assign(socket,
             page_title: prototype.title,
             prototype: prototype,
             owner?: owner?,
             admin?: admin?,
             lightbox_index: nil
           )}
        end

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Prototype not found"))
         |> redirect(to: ~p"/prototypes")}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("open_lightbox", %{"index" => idx}, socket) do
    {:noreply, assign(socket, lightbox_index: String.to_integer(idx))}
  end

  def handle_event("close_lightbox", _params, socket) do
    {:noreply, assign(socket, lightbox_index: nil)}
  end

  def handle_event("prev_image", _params, socket) do
    {:noreply, shift_lightbox(socket, -1)}
  end

  def handle_event("next_image", _params, socket) do
    {:noreply, shift_lightbox(socket, +1)}
  end

  def handle_event("lightbox_key", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, lightbox_index: nil)}
  end

  def handle_event("lightbox_key", %{"key" => "ArrowLeft"}, socket) do
    {:noreply, shift_lightbox(socket, -1)}
  end

  def handle_event("lightbox_key", %{"key" => "ArrowRight"}, socket) do
    {:noreply, shift_lightbox(socket, +1)}
  end

  def handle_event("lightbox_key", _params, socket), do: {:noreply, socket}

  def handle_event("delete", _params, socket) do
    case Prototypes.delete_prototype(socket.assigns.prototype, socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Prototype deleted"))
         |> redirect(to: ~p"/prototypes")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, gettext("You can't delete that prototype"))}
    end
  end

  defp shift_lightbox(socket, delta) do
    case socket.assigns.lightbox_index do
      nil ->
        socket

      idx ->
        total = length(socket.assigns.prototype.images)
        new_idx = idx + delta
        if new_idx in 0..(total - 1), do: assign(socket, lightbox_index: new_idx), else: socket
    end
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-6">
      <.link
        navigate={~p"/prototypes"}
        class="inline-flex items-center text-sm font-heading hover:bg-main px-2 py-1 rounded-base"
      >
        ← {gettext("Back to prototypes")}
      </.link>

      <div
        :if={@prototype.blocked_at}
        class="rounded-base border-2 border-border bg-red-300 p-4 shadow-brutalist"
      >
        <p class="font-heading text-sm">
          {gettext("This prototype has been blocked by an admin and is hidden from other users.")}
        </p>
      </div>

      <div class="rounded-base border-2 border-border bg-bw shadow-brutalist overflow-hidden">
        <div :if={@prototype.images != []} class="grid grid-cols-2 sm:grid-cols-3 gap-2 p-4 bg-bg">
          <button
            :for={{image, idx} <- Enum.with_index(@prototype.images)}
            type="button"
            phx-click="open_lightbox"
            phx-value-index={idx}
            aria-label={gettext("View image %{n}", n: idx + 1)}
            class="block aspect-square rounded-base border-2 border-border overflow-hidden bg-bw hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            <img
              src={~p"/prototype_images/#{image.id}"}
              alt={image.original_filename}
              class="w-full h-full object-cover"
              loading="lazy"
            />
          </button>
        </div>

        <div class="p-6 space-y-6">
          <div>
            <h1 class="text-3xl font-heading mb-2">{@prototype.title}</h1>
            <p class="text-sm font-base text-fg/70">
              {gettext("Submitted by")}
              <span class="font-heading">{@prototype.user.username}</span>
            </p>
          </div>

          <div class="flex flex-wrap gap-2 text-sm font-base">
            <span class="inline-flex items-center rounded-base border-2 border-border bg-bg px-3 py-1">
              {gettext("%{min}-%{max} players",
                min: @prototype.min_players,
                max: @prototype.max_players
              )}
            </span>
            <span class="inline-flex items-center rounded-base border-2 border-border bg-bg px-3 py-1">
              {gettext("%{min}-%{max} min",
                min: @prototype.min_playtime,
                max: @prototype.max_playtime
              )}
            </span>
          </div>

          <section>
            <h2 class="text-sm font-heading uppercase tracking-wide mb-2">
              {gettext("Description")}
            </h2>
            <p class="font-base whitespace-pre-line">{@prototype.description}</p>
          </section>

          <section :if={@prototype.categories != []}>
            <h2 class="text-sm font-heading uppercase tracking-wide mb-2">
              {gettext("Categories")}
            </h2>
            <div class="flex flex-wrap gap-2">
              <span
                :for={c <- @prototype.categories}
                class="inline-flex items-center rounded-base border-2 border-border bg-main px-2 py-0.5 text-xs font-heading"
              >
                {c}
              </span>
            </div>
          </section>

          <section :if={@prototype.mechanics != []}>
            <h2 class="text-sm font-heading uppercase tracking-wide mb-2">
              {gettext("Mechanics")}
            </h2>
            <div class="flex flex-wrap gap-2">
              <span
                :for={m <- @prototype.mechanics}
                class="inline-flex items-center rounded-base border-2 border-border bg-bg px-2 py-0.5 text-xs font-heading"
              >
                {m}
              </span>
            </div>
          </section>

          <section :if={@prototype.collaborators != []}>
            <h2 class="text-sm font-heading uppercase tracking-wide mb-2">
              {gettext("Team")}
            </h2>
            <ul class="space-y-1 font-base">
              <li :for={collab <- @prototype.collaborators}>
                <span class="font-heading">{collab.name}</span> — {collab.role}
              </li>
            </ul>
          </section>

          <section>
            <h2 class="text-sm font-heading uppercase tracking-wide mb-2">
              {gettext("Contact")}
            </h2>
            <a
              href={"mailto:#{@prototype.contact_email}"}
              class="font-base underline decoration-2 underline-offset-2 hover:bg-main"
            >
              {@prototype.contact_email}
            </a>
          </section>

          <div :if={@owner?} class="flex gap-3 pt-4 border-t-2 border-border">
            <.link
              navigate={~p"/prototypes/#{@prototype.id}/edit"}
              class="rounded-base border-2 border-border bg-bw px-4 py-2 text-sm font-heading shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
            >
              {gettext("Edit")}
            </.link>
            <button
              phx-click="delete"
              data-confirm={gettext("Delete this prototype? This cannot be undone.")}
              class="rounded-base border-2 border-border bg-red-300 px-4 py-2 text-sm font-heading shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
            >
              {gettext("Delete")}
            </button>
          </div>
        </div>
      </div>

    </div>
    <.lightbox :if={not is_nil(@lightbox_index)} prototype={@prototype} index={@lightbox_index} />
    """
  end

  attr :prototype, :map, required: true
  attr :index, :integer, required: true

  defp lightbox(assigns) do
    total = length(assigns.prototype.images)
    image = Enum.at(assigns.prototype.images, assigns.index)

    assigns =
      assign(assigns,
        image: image,
        total: total,
        has_prev?: assigns.index > 0,
        has_next?: assigns.index < total - 1
      )

    ~H"""
    <div
      id="prototype-lightbox"
      role="dialog"
      aria-modal="true"
      aria-label={gettext("Image viewer")}
      phx-window-keyup="lightbox_key"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/80"
    >
      <div phx-click="close_lightbox" class="absolute inset-0" aria-hidden="true"></div>

      <button
        type="button"
        phx-click="close_lightbox"
        aria-label={gettext("Close")}
        class="absolute top-4 right-4 z-10 rounded-base border-2 border-border bg-bw w-10 h-10 flex items-center justify-center font-heading text-xl hover:bg-main transition-colors"
      >
        ×
      </button>

      <button
        :if={@has_prev?}
        type="button"
        phx-click="prev_image"
        aria-label={gettext("Previous image")}
        class="absolute left-4 top-1/2 -translate-y-1/2 z-10 rounded-base border-2 border-border bg-bw w-12 h-12 flex items-center justify-center font-heading text-2xl hover:bg-main transition-colors"
      >
        ‹
      </button>

      <button
        :if={@has_next?}
        type="button"
        phx-click="next_image"
        aria-label={gettext("Next image")}
        class="absolute right-4 top-1/2 -translate-y-1/2 z-10 rounded-base border-2 border-border bg-bw w-12 h-12 flex items-center justify-center font-heading text-2xl hover:bg-main transition-colors"
      >
        ›
      </button>

      <div class="relative max-w-[90vw] max-h-[85vh] flex items-center justify-center">
        <img
          src={~p"/prototype_images/#{@image.id}"}
          alt={@image.original_filename}
          class="max-w-full max-h-[85vh] object-contain rounded-base border-2 border-border bg-bw"
        />
      </div>

      <p class="absolute bottom-4 left-1/2 -translate-x-1/2 rounded-base border-2 border-border bg-bw px-3 py-1 text-sm font-heading">
        {@index + 1} / {@total}
      </p>
    </div>
    """
  end
end
