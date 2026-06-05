defmodule ReccoWeb.PrototypeLive.Show do
  use ReccoWeb, :live_view

  alias Recco.Prototypes

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"id" => id}, _session, socket) do
    case Prototypes.get_prototype(id) do
      {:ok, prototype} ->
        {:ok,
         assign(socket,
           page_title: prototype.title,
           prototype: prototype,
           owner?: Prototypes.owns?(prototype, socket.assigns.current_user)
         )}

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

      <div class="rounded-base border-2 border-border bg-bw shadow-brutalist overflow-hidden">
        <div :if={@prototype.images != []} class="grid grid-cols-2 sm:grid-cols-3 gap-2 p-4 bg-bg">
          <a
            :for={image <- @prototype.images}
            href={~p"/prototype_images/#{image.id}"}
            target="_blank"
            class="block aspect-square rounded-base border-2 border-border overflow-hidden bg-bw hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            <img
              src={~p"/prototype_images/#{image.id}"}
              alt={image.original_filename}
              class="w-full h-full object-cover"
              loading="lazy"
            />
          </a>
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
    """
  end
end
