defmodule ReccoWeb.GameLive.Index do
  use ReccoWeb, :live_view

  alias Recco.BoardGames

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
    search = params["search"] || ""
    category = params["category"] || ""
    mechanic = params["mechanic"] || ""
    sort = params["sort"] || "rating"

    opts =
      %{page: page, per_page: @per_page, sort: sort}
      |> maybe_put(:search, search)
      |> maybe_put(:category, category)
      |> maybe_put(:mechanic, mechanic)

    %{games: games, total: total} = BoardGames.list_board_games(opts)
    total_pages = max(ceil(total / @per_page), 1)

    {:noreply,
     assign(socket,
       page_title: "Browse Games",
       games: games,
       total: total,
       page: page,
       total_pages: total_pages,
       search: search,
       category: category,
       mechanic: mechanic,
       sort: sort
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("search", %{"search" => search}, socket) do
    params = build_params(socket.assigns, search: search, page: 1)
    {:noreply, push_patch(socket, to: ~p"/games?#{params}")}
  end

  def handle_event("filter", params, socket) do
    filter_params =
      build_params(socket.assigns,
        category: params["category"] || "",
        mechanic: params["mechanic"] || "",
        page: 1
      )

    {:noreply, push_patch(socket, to: ~p"/games?#{filter_params}")}
  end

  def handle_event("sort", %{"sort" => sort}, socket) do
    params = build_params(socket.assigns, sort: sort, page: 1)
    {:noreply, push_patch(socket, to: ~p"/games?#{params}")}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold text-zinc-900 mb-6">Browse Games</h1>

      <div class="mb-6 flex flex-col sm:flex-row gap-4">
        <form phx-change="search" phx-submit="search" class="flex-1">
          <.input
            name="search"
            type="text"
            value={@search}
            placeholder="Search games..."
            phx-debounce="300"
          />
        </form>

        <form phx-change="sort" class="w-full sm:w-48">
          <select
            name="sort"
            class="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm"
            aria-label="Sort by"
          >
            <option value="rating" selected={@sort == "rating"}>Top rated</option>
            <option value="name" selected={@sort == "name"}>Name</option>
            <option value="year" selected={@sort == "year"}>Newest</option>
            <option value="weight" selected={@sort == "weight"}>Heaviest</option>
          </select>
        </form>
      </div>

      <p class="text-sm text-zinc-500 mb-4">
        {@total} games found
      </p>

      <div :if={@games == []} class="text-center py-16 text-zinc-500">
        No games found. Try a different search.
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <.game_card :for={game <- @games} game={game} />
      </div>

      <.pagination
        :if={@total_pages > 1}
        page={@page}
        total_pages={@total_pages}
        params={build_params(assigns)}
      />
    </div>
    """
  end

  attr :game, :map, required: true

  defp game_card(assigns) do
    ~H"""
    <a
      href={~p"/games/#{@game.id}"}
      class="block rounded-lg border border-zinc-200 hover:border-zinc-300 hover:shadow-sm transition overflow-hidden"
    >
      <div class="aspect-square bg-zinc-100 flex items-center justify-center">
        <img
          :if={@game.image_url}
          src={@game.image_url}
          alt={@game.name}
          class="max-w-full max-h-full object-contain"
          loading="lazy"
        />
      </div>
      <div class="p-3">
        <h2 class="font-semibold text-zinc-900 text-sm truncate">{@game.name}</h2>
        <div class="flex items-center justify-between mt-1 text-xs text-zinc-500">
          <span :if={@game.year_published}>{@game.year_published}</span>
          <span :if={@game.average_rating} class="font-medium text-zinc-700">
            {Float.round(@game.average_rating, 1)}
          </span>
        </div>
        <div :if={@game.min_players && @game.max_players} class="text-xs text-zinc-500 mt-1">
          {@game.min_players}-{@game.max_players} players
        </div>
      </div>
    </a>
    """
  end

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :params, :map, required: true

  defp pagination(assigns) do
    ~H"""
    <nav class="mt-8 flex justify-center gap-2" aria-label="Pagination">
      <.page_link
        :if={@page > 1}
        page={@page - 1}
        params={@params}
        label="Previous"
      />

      <.page_link
        :for={p <- page_range(@page, @total_pages)}
        page={p}
        params={@params}
        label={to_string(p)}
        current={p == @page}
      />

      <.page_link
        :if={@page < @total_pages}
        page={@page + 1}
        params={@params}
        label="Next"
      />
    </nav>
    """
  end

  attr :page, :integer, required: true
  attr :params, :map, required: true
  attr :label, :string, required: true
  attr :current, :boolean, default: false

  defp page_link(assigns) do
    params = Map.put(assigns.params, "page", assigns.page)
    assigns = assign(assigns, :href, ~p"/games?#{params}")

    ~H"""
    <a
      href={@href}
      class={[
        "px-3 py-2 text-sm rounded-lg",
        @current && "bg-brand-600 text-white",
        !@current && "text-zinc-600 hover:bg-zinc-100"
      ]}
      aria-current={@current && "page"}
    >
      {@label}
    </a>
    """
  end

  defp page_range(current, total) do
    start = max(1, current - 2)
    finish = min(total, current + 2)
    Enum.to_list(start..finish)
  end

  defp build_params(assigns, overrides \\ []) do
    %{
      "search" => Keyword.get(overrides, :search, assigns.search),
      "category" => Keyword.get(overrides, :category, assigns.category),
      "mechanic" => Keyword.get(overrides, :mechanic, assigns.mechanic),
      "sort" => Keyword.get(overrides, :sort, assigns.sort),
      "page" => Keyword.get(overrides, :page, assigns.page)
    }
    |> Enum.reject(fn {_k, v} -> v in ["", nil, 1, "rating"] end)
    |> Map.new()
  end

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end

  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
