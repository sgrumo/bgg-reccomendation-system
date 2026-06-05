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

    opts =
      %{page: page, per_page: @per_page}
      |> maybe_scope_to_user(mine?, socket.assigns.current_user)

    %{prototypes: prototypes, total: total} = Prototypes.list_prototypes(opts)
    total_pages = max(ceil(total / @per_page), 1)

    {:noreply,
     assign(socket,
       page_title: gettext("Prototypes"),
       prototypes: prototypes,
       total: total,
       page: page,
       total_pages: total_pages,
       mine?: mine?
     )}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
        <h1 class="text-2xl font-heading">{gettext("Prototypes")}</h1>
        <.link
          navigate={~p"/prototypes/new"}
          class="inline-flex items-center justify-center rounded-base border-2 border-border bg-main px-4 py-2 text-sm font-heading shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
        >
          {gettext("Submit a prototype")}
        </.link>
      </div>

      <div class="mb-6 flex gap-2">
        <.link
          patch={~p"/prototypes"}
          class={[
            "px-3 py-1.5 rounded-base border-2 border-border text-sm font-heading transition-colors",
            !@mine? && "bg-main shadow-brutalist",
            @mine? && "bg-bw hover:bg-bg"
          ]}
        >
          {gettext("All")}
        </.link>
        <.link
          patch={~p"/prototypes?mine=1"}
          class={[
            "px-3 py-1.5 rounded-base border-2 border-border text-sm font-heading transition-colors",
            @mine? && "bg-main shadow-brutalist",
            !@mine? && "bg-bw hover:bg-bg"
          ]}
        >
          {gettext("Mine")}
        </.link>
      </div>

      <p class="text-sm font-base mb-4">
        {ngettext("%{count} prototype", "%{count} prototypes", @total)}
      </p>

      <div
        :if={@prototypes == []}
        class="text-center py-16 rounded-base border-2 border-border bg-bw shadow-brutalist"
      >
        <p class="font-base">{gettext("No prototypes yet. Be the first to submit one!")}</p>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <.prototype_card :for={prototype <- @prototypes} prototype={prototype} />
      </div>

      <.pagination :if={@total_pages > 1} page={@page} total_pages={@total_pages} mine?={@mine?} />
    </div>
    """
  end

  attr :prototype, :map, required: true

  defp prototype_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/prototypes/#{@prototype.id}"}
      class="block rounded-base border-2 border-border bg-bw shadow-brutalist overflow-hidden hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
    >
      <div class="aspect-video bg-bg border-b-2 border-border flex items-center justify-center overflow-hidden">
        <img
          :if={cover_image(@prototype)}
          src={~p"/prototype_images/#{cover_image(@prototype).id}"}
          alt={@prototype.title}
          class="w-full h-full object-cover"
          loading="lazy"
        />
        <span :if={!cover_image(@prototype)} class="font-heading text-fg/40 text-sm">
          {gettext("No image")}
        </span>
      </div>
      <div class="p-4 space-y-2">
        <h2 class="font-heading truncate">{@prototype.title}</h2>
        <div class="flex flex-wrap gap-2 text-xs font-base">
          <span class="inline-flex items-center rounded-base border-2 border-border bg-bg px-2 py-0.5">
            {gettext("%{min}-%{max} players",
              min: @prototype.min_players,
              max: @prototype.max_players
            )}
          </span>
          <span class="inline-flex items-center rounded-base border-2 border-border bg-bg px-2 py-0.5">
            {gettext("%{min}-%{max} min",
              min: @prototype.min_playtime,
              max: @prototype.max_playtime
            )}
          </span>
        </div>
        <p :if={@prototype.categories != []} class="text-xs font-base text-fg/70 truncate">
          {Enum.join(Enum.take(@prototype.categories, 3), " · ")}
        </p>
      </div>
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
        "px-3 py-2 text-sm font-heading rounded-base border-2 border-border transition-all",
        @current && "bg-main shadow-brutalist",
        !@current && "bg-bw hover:bg-main"
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

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end
end
