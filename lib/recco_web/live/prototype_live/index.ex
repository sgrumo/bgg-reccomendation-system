defmodule ReccoWeb.PrototypeLive.Index do
  use ReccoWeb, :live_view

  alias Recco.Prototypes

  @per_page 24

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    mine? = params["mine"] == "1"
    liked? = params["liked"] == "1"
    user = socket.assigns.current_user

    opts =
      %{page: page, per_page: @per_page}
      |> maybe_scope_to_user(mine?, user)
      |> maybe_scope_to_liked(liked?, user)

    %{prototypes: prototypes, total: total} = Prototypes.list_prototypes(opts)
    total_pages = max(ceil(total / @per_page), 1)
    liked_ids = Prototypes.user_liked_ids(user.id, Enum.map(prototypes, & &1.id))

    {:noreply,
     assign(socket,
       page_title: gettext("Prototypes"),
       prototypes: prototypes,
       total: total,
       page: page,
       total_pages: total_pages,
       mine?: mine?,
       liked?: liked?,
       liked_ids: liked_ids
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("toggle_like", %{"id" => prototype_id}, socket) do
    user_id = socket.assigns.current_user.id

    new_liked_ids =
      if MapSet.member?(socket.assigns.liked_ids, prototype_id) do
        :ok = Prototypes.unlike_prototype(user_id, prototype_id)
        MapSet.delete(socket.assigns.liked_ids, prototype_id)
      else
        case Prototypes.like_prototype(user_id, prototype_id) do
          {:ok, _} -> MapSet.put(socket.assigns.liked_ids, prototype_id)
          {:error, _, _} -> socket.assigns.liked_ids
        end
      end

    socket = assign(socket, liked_ids: new_liked_ids)

    if socket.assigns.liked? do
      {:noreply, push_patch(socket, to: ~p"/prototypes?liked=1")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="pb-12">
      <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 mb-6">
        <div>
          <div class="label mb-2">{gettext("Community")}</div>
          <h1 class="text-[clamp(34px,4vw,58px)]">{gettext("Prototypes")}</h1>
        </div>
        <.link navigate={~p"/prototypes/new"} class="btn btn-primary self-start sm:self-end">
          {gettext("Submit a prototype")} →
        </.link>
      </div>

      <div class="mb-6 flex gap-2 flex-wrap">
        <.filter_tab active?={!@mine? and !@liked?} href={~p"/prototypes"} label={gettext("All")} />
        <.filter_tab active?={@mine?} href={~p"/prototypes?mine=1"} label={gettext("Mine")} />
        <.filter_tab active?={@liked?} href={~p"/prototypes?liked=1"} label={gettext("Liked")} />
      </div>

      <p class="label mb-3">
        {ngettext("%{count} prototype", "%{count} prototypes", @total)}
      </p>

      <div :if={@prototypes == []} class="panel px-6 py-12 text-center">
        <p class="text-ink-soft text-[17px]">
          {gettext("No prototypes yet. Be the first to submit one!")}
        </p>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <.prototype_card
          :for={prototype <- @prototypes}
          prototype={prototype}
          liked?={MapSet.member?(@liked_ids, prototype.id)}
        />
      </div>

      <.pagination :if={@total_pages > 1} page={@page} total_pages={@total_pages} mine?={@mine?} />
    </div>
    """
  end

  attr :prototype, :map, required: true
  attr :liked?, :boolean, required: true

  defp prototype_card(assigns) do
    ~H"""
    <article class="panel lift relative overflow-hidden flex flex-col">
      <.link navigate={~p"/prototypes/#{@prototype.id}"} class="block">
        <div class="aspect-video bg-card2 border-b-bw border-line grid place-items-center overflow-hidden">
          <img
            :if={cover_image(@prototype)}
            src={~p"/prototype_images/#{cover_image(@prototype).id}"}
            alt={@prototype.title}
            class="w-full h-full object-cover"
            loading="lazy"
          />
          <span :if={!cover_image(@prototype)} class="text-ink-soft text-sm">
            {gettext("No image")}
          </span>
        </div>
        <div class="p-4 space-y-2.5">
          <h3 class="text-[19px] leading-tight truncate">{@prototype.title}</h3>
          <div class="flex flex-wrap gap-2 font-mono text-ink-soft text-[12.5px]">
            <span>
              {gettext("%{min}-%{max} players",
                min: @prototype.min_players,
                max: @prototype.max_players
              )}
            </span>
            <span>
              {gettext("%{min}-%{max} min",
                min: @prototype.min_playtime,
                max: @prototype.max_playtime
              )}
            </span>
          </div>
          <p :if={@prototype.categories != []} class="text-ink-soft text-xs truncate">
            {Enum.join(Enum.take(@prototype.categories, 3), " · ")}
          </p>
        </div>
      </.link>
      <button
        type="button"
        phx-click="toggle_like"
        phx-value-id={@prototype.id}
        aria-pressed={to_string(@liked?)}
        aria-label={if @liked?, do: gettext("Unlike"), else: gettext("Like")}
        class={[
          "btn btn-sm absolute top-2.5 right-2.5 !p-2 !text-lg leading-none",
          @liked? && "!bg-danger !text-accent-ink"
        ]}
      >
        {if @liked?, do: "♥", else: "♡"}
      </button>
    </article>
    """
  end

  attr :active?, :boolean, required: true
  attr :href, :string, required: true
  attr :label, :string, required: true

  defp filter_tab(assigns) do
    ~H"""
    <.link
      patch={@href}
      class={[
        "btn btn-sm",
        @active? && "btn-primary",
        !@active? && "btn-ghost"
      ]}
      aria-current={@active? && "page"}
    >
      {@label}
    </.link>
    """
  end

  defp cover_image(%{images: [first | _]}), do: first
  defp cover_image(_), do: nil

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :mine?, :boolean, required: true

  defp pagination(assigns) do
    ~H"""
    <nav class="mt-8 flex justify-center gap-2" aria-label="Pagination">
      <.page_link
        :if={@page > 1}
        page={@page - 1}
        mine?={@mine?}
        label={gettext("Previous")}
      />
      <.page_link
        :for={p <- page_range(@page, @total_pages)}
        page={p}
        mine?={@mine?}
        label={to_string(p)}
        current={p == @page}
      />
      <.page_link
        :if={@page < @total_pages}
        page={@page + 1}
        mine?={@mine?}
        label={gettext("Next")}
      />
    </nav>
    """
  end

  attr :page, :integer, required: true
  attr :mine?, :boolean, required: true
  attr :label, :string, required: true
  attr :current, :boolean, default: false

  defp page_link(assigns) do
    params =
      %{"page" => assigns.page}
      |> then(&if assigns.mine?, do: Map.put(&1, "mine", "1"), else: &1)

    assigns = assign(assigns, :href, ~p"/prototypes?#{params}")

    ~H"""
    <.link
      patch={@href}
      class={[
        "btn btn-sm",
        @current && "btn-primary",
        !@current && "btn-ghost"
      ]}
      aria-current={@current && "page"}
    >
      {@label}
    </.link>
    """
  end

  defp page_range(current, total) do
    start = max(1, current - 2)
    finish = min(total, current + 2)
    Enum.to_list(start..finish)
  end

  defp maybe_scope_to_user(opts, true, %{id: user_id}), do: Map.put(opts, :user_id, user_id)
  defp maybe_scope_to_user(opts, _, _), do: opts

  defp maybe_scope_to_liked(opts, true, %{id: user_id}), do: Map.put(opts, :liked_by, user_id)
  defp maybe_scope_to_liked(opts, _, _), do: opts

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end
end
