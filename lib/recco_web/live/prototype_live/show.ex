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
             lightbox_index: nil,
             liked?: Prototypes.liked?(user.id, prototype.id),
             like_count: Prototypes.count_likes(prototype.id)
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

  def handle_event("toggle_like", _params, socket) do
    user_id = socket.assigns.current_user.id
    prototype_id = socket.assigns.prototype.id

    if socket.assigns.liked? do
      :ok = Prototypes.unlike_prototype(user_id, prototype_id)
      {:noreply, assign(socket, liked?: false, like_count: socket.assigns.like_count - 1)}
    else
      case Prototypes.like_prototype(user_id, prototype_id) do
        {:ok, _} ->
          {:noreply, assign(socket, liked?: true, like_count: socket.assigns.like_count + 1)}

        {:error, _, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not save like"))}
      end
    end
  end

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
    <div class="max-w-4xl mx-auto pb-12 space-y-6">
      <.link navigate={~p"/prototypes"} class="btn btn-ghost btn-sm !pl-0">
        ← {gettext("Back to prototypes")}
      </.link>

      <div :if={@prototype.blocked_at} class="panel !bg-danger !text-accent-ink p-4">
        <p class="font-bold text-sm">
          {gettext("This prototype has been blocked by an admin and is hidden from other users.")}
        </p>
      </div>

      <div class="panel overflow-hidden">
        <div :if={@prototype.images != []} class="grid grid-cols-2 sm:grid-cols-3 gap-2 p-4 bg-card2">
          <button
            :for={{image, idx} <- Enum.with_index(@prototype.images)}
            type="button"
            phx-click="open_lightbox"
            phx-value-index={idx}
            aria-label={gettext("View image %{n}", n: idx + 1)}
            class="block aspect-square border-bw border-line rounded-panel-sm overflow-hidden bg-card hover:-translate-x-0.5 hover:-translate-y-0.5 hover:shadow-panel-sm transition-transform"
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
          <div class="flex items-start justify-between gap-4 flex-wrap">
            <div>
              <div class="label mb-2">
                {gettext("Submitted by")} <span class="!text-ink">{@prototype.user.username}</span>
              </div>
              <h1 class="text-[clamp(34px,4vw,58px)]">{@prototype.title}</h1>
            </div>
            <button
              type="button"
              phx-click="toggle_like"
              aria-pressed={to_string(@liked?)}
              aria-label={if @liked?, do: gettext("Unlike"), else: gettext("Like")}
              class={[
                "btn !gap-2",
                @liked? && "!bg-danger !text-accent-ink"
              ]}
            >
              <span aria-hidden="true">{if @liked?, do: "♥", else: "♡"}</span>
              <span class="font-mono tabular-nums">{@like_count}</span>
            </button>
          </div>

          <div class="flex flex-wrap gap-2 font-mono text-ink-soft text-[13px]">
            <span>
              {gettext("%{min}-%{max} players",
                min: @prototype.min_players,
                max: @prototype.max_players
              )}
            </span>
            <span aria-hidden="true">·</span>
            <span>
              {gettext("%{min}-%{max} min",
                min: @prototype.min_playtime,
                max: @prototype.max_playtime
              )}
            </span>
          </div>

          <section>
            <div class="label mb-2.5">{gettext("Description")}</div>
            <p class="text-[16.5px] leading-[1.62] whitespace-pre-line">{@prototype.description}</p>
          </section>

          <section :if={@prototype.categories != []}>
            <div class="label mb-2.5">{gettext("Categories")}</div>
            <div class="flex flex-wrap gap-2">
              <span :for={c <- @prototype.categories} class="chip chip-accent">{c}</span>
            </div>
          </section>

          <section :if={@prototype.mechanics != []}>
            <div class="label mb-2.5">{gettext("Mechanics")}</div>
            <div class="flex flex-wrap gap-2">
              <span :for={m <- @prototype.mechanics} class="chip">{m}</span>
            </div>
          </section>

          <section :if={@prototype.collaborators != []}>
            <div class="label mb-2.5">{gettext("Team")}</div>
            <ul class="space-y-1">
              <li :for={collab <- @prototype.collaborators}>
                <span class="font-bold">{collab.name}</span>
                <span class="text-ink-soft">— {collab.role}</span>
              </li>
            </ul>
          </section>

          <section :if={@prototype.links != []}>
            <div class="label mb-2.5">{gettext("Links")}</div>
            <ul class="flex flex-wrap gap-2">
              <li :for={link <- @prototype.links}>
                <a
                  href={link.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="btn btn-sm"
                >
                  {link.label} <span aria-hidden="true">↗</span>
                </a>
              </li>
            </ul>
          </section>

          <section>
            <div class="label mb-2.5">{gettext("Contact")}</div>
            <a
              href={"mailto:#{@prototype.contact_email}"}
              class="font-bold underline decoration-2 underline-offset-2"
            >
              {@prototype.contact_email}
            </a>
          </section>

          <div :if={@owner?} class="flex gap-3 pt-5 border-t-bw border-line">
            <.link navigate={~p"/prototypes/#{@prototype.id}/edit"} class="btn">
              {gettext("Edit")}
            </.link>
            <button
              type="button"
              phx-click="delete"
              data-confirm={gettext("Delete this prototype? This cannot be undone.")}
              class="btn hover:!bg-danger hover:!text-accent-ink"
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
        class="btn btn-sm absolute top-4 right-4 z-10 !w-10 !h-10 !p-0 grid place-items-center text-xl"
      >
        ×
      </button>

      <button
        :if={@has_prev?}
        type="button"
        phx-click="prev_image"
        aria-label={gettext("Previous image")}
        class="btn absolute left-4 top-1/2 -translate-y-1/2 z-10 !w-12 !h-12 !p-0 grid place-items-center text-2xl"
      >
        ‹
      </button>

      <button
        :if={@has_next?}
        type="button"
        phx-click="next_image"
        aria-label={gettext("Next image")}
        class="btn absolute right-4 top-1/2 -translate-y-1/2 z-10 !w-12 !h-12 !p-0 grid place-items-center text-2xl"
      >
        ›
      </button>

      <div class="relative max-w-[90vw] max-h-[85vh] flex items-center justify-center">
        <img
          src={~p"/prototype_images/#{@image.id}"}
          alt={@image.original_filename}
          class="max-w-full max-h-[85vh] object-contain border-bw border-line rounded-panel bg-card"
        />
      </div>

      <p class="absolute bottom-4 left-1/2 -translate-x-1/2 rounded-base border-2 border-border bg-bw px-3 py-1 text-sm font-heading">
        {@index + 1} / {@total}
      </p>
    </div>
    """
  end
end
