defmodule ReccoWeb.GameLive.Index do
  use ReccoWeb, :live_view

  alias Recco.BoardGames

  @per_page 24

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       all_categories: BoardGames.list_categories(),
       all_mechanics: BoardGames.list_mechanics()
     )}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    search = params["search"] || ""
    categories = parse_list(params["categories"])
    mechanics = parse_list(params["mechanics"])
    sort = params["sort"] || "rating"
    sort_dir = params["sort_dir"]

    opts =
      %{page: page, per_page: @per_page, sort: sort}
      |> maybe_put(:search, search)
      |> maybe_put(:sort_dir, sort_dir)
      |> maybe_put_list(:categories, categories)
      |> maybe_put_list(:mechanics, mechanics)

    %{games: games, total: total} = BoardGames.list_board_games(opts)
    total_pages = max(ceil(total / @per_page), 1)

    {:noreply,
     assign(socket,
       page_title: gettext("Browse Games"),
       games: games,
       total: total,
       page: page,
       total_pages: total_pages,
       search: search,
       categories: categories,
       mechanics: mechanics,
       sort: sort,
       sort_dir: sort_dir || default_dir(sort)
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("search", %{"search" => search}, socket) do
    params = build_params(socket.assigns, search: search, page: 1)
    {:noreply, push_patch(socket, to: ~p"/games?#{params}")}
  end

  def handle_event("filter_categories", %{"selected" => selected}, socket) do
    params = build_params(socket.assigns, categories: selected, page: 1)
    {:noreply, push_patch(socket, to: ~p"/games?#{params}")}
  end

  def handle_event("filter_mechanics", %{"selected" => selected}, socket) do
    params = build_params(socket.assigns, mechanics: selected, page: 1)
    {:noreply, push_patch(socket, to: ~p"/games?#{params}")}
  end

  def handle_event("clear_filters", _params, socket) do
    params = build_params(socket.assigns, categories: [], mechanics: [], page: 1)
    {:noreply, push_patch(socket, to: ~p"/games?#{params}")}
  end

  def handle_event("sort", %{"sort" => sort}, socket) do
    params = build_params(socket.assigns, sort: sort, sort_dir: default_dir(sort), page: 1)
    {:noreply, push_patch(socket, to: ~p"/games?#{params}")}
  end

  def handle_event("toggle_sort_dir", _params, socket) do
    new_dir = if socket.assigns.sort_dir == "asc", do: "desc", else: "asc"
    params = build_params(socket.assigns, sort_dir: new_dir, page: 1)
    {:noreply, push_patch(socket, to: ~p"/games?#{params}")}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-heading mb-6">{gettext("Browse Games")}</h1>

      <div class="mb-6 flex flex-col sm:flex-row gap-4">
        <form phx-change="search" phx-submit="search" class="flex-1">
          <.input
            name="search"
            type="text"
            value={@search}
            placeholder={gettext("Search games...")}
            phx-debounce="300"
          />
        </form>

        <div class="flex gap-2 w-full sm:w-auto">
          <form phx-change="sort" class="flex-1 sm:w-48">
            <select
              name="sort"
              class="w-full h-10 rounded-base border-2 border-border bg-bw px-3 py-2 text-sm font-base focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
              aria-label={gettext("Sort by")}
            >
              <option value="rating" selected={@sort == "rating"}>{gettext("Top rated")}</option>
              <option value="name" selected={@sort == "name"}>{gettext("Name")}</option>
              <option value="year" selected={@sort == "year"}>{gettext("Newest")}</option>
              <option value="weight" selected={@sort == "weight"}>{gettext("Heaviest")}</option>
            </select>
          </form>
          <button
            phx-click="toggle_sort_dir"
            class="h-10 w-10 flex items-center justify-center rounded-base border-2 border-border bg-bw hover:bg-bg transition-colors flex-shrink-0"
            aria-label={gettext("Toggle sort direction")}
            title={if @sort_dir == "asc", do: gettext("Ascending"), else: gettext("Descending")}
          >
            <svg
              :if={@sort_dir == "asc"}
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              class="w-5 h-5"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M4.5 10.5 12 3m0 0 7.5 7.5M12 3v18"
              />
            </svg>
            <svg
              :if={@sort_dir != "asc"}
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              class="w-5 h-5"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M19.5 13.5 12 21m0 0-7.5-7.5M12 21V3"
              />
            </svg>
          </button>
        </div>
      </div>

      <div class="mb-6 flex flex-col sm:flex-row gap-4">
        <.multi_select
          id="category-filter"
          label={gettext("Categories")}
          options={@all_categories}
          selected={@categories}
          event="filter_categories"
          placeholder={gettext("All categories")}
        />
        <.multi_select
          id="mechanic-filter"
          label={gettext("Mechanics")}
          options={@all_mechanics}
          selected={@mechanics}
          event="filter_mechanics"
          placeholder={gettext("All mechanics")}
        />
      </div>

      <button
        :if={@categories != [] or @mechanics != []}
        phx-click="clear_filters"
        class="mb-4 rounded-base border-2 border-border bg-bw px-3 py-1.5 text-sm font-heading hover:bg-bg transition-colors"
      >
        {gettext("Clear all filters")}
      </button>

      <p class="text-sm font-base mb-4">
        {ngettext("%{count} game found", "%{count} games found", @total)}
      </p>

      <div
        :if={@games == []}
        class="text-center py-16 rounded-base border-2 border-border bg-bw shadow-brutalist"
      >
        <p class="font-base">{gettext("No games found. Try a different search.")}</p>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
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
      class="block rounded-base border-2 border-border bg-bw shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all overflow-hidden"
    >
      <div class="aspect-square bg-bg flex items-center justify-center border-b-2 border-border">
        <img
          :if={@game.image_url}
          src={@game.image_url}
          alt={@game.name}
          class="max-w-full max-h-full object-contain"
          loading="lazy"
        />
      </div>
      <div class="p-3">
        <h2 class="font-heading text-sm truncate">{@game.name}</h2>
        <div class="flex items-center justify-between mt-1 text-xs font-base">
          <span :if={@game.year_published}>{@game.year_published}</span>
          <span
            :if={@game.average_rating}
            class="inline-flex items-center rounded-base border-2 border-border bg-main px-1.5 py-0.5 text-xs font-heading"
          >
            {Float.round(@game.average_rating, 1)}
          </span>
        </div>
        <div class="flex items-center justify-between mt-1 text-xs font-base">
          <span :if={@game.min_players && @game.max_players}>
            {gettext("%{min}-%{max} players", min: @game.min_players, max: @game.max_players)}
          </span>
          <span :if={@game.users_rated}>
            {ngettext("%{count} vote", "%{count} votes", @game.users_rated)}
          </span>
        </div>
      </div>
    </a>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true
  attr :selected, :list, required: true
  attr :event, :string, required: true
  attr :placeholder, :string, default: "Select..."

  defp multi_select(assigns) do
    options_json = Jason.encode!(Enum.map(assigns.options, &%{name: &1.name}))
    selected_json = Jason.encode!(assigns.selected)
    assigns = assign(assigns, options_json: options_json, selected_json: selected_json)

    ~H"""
    <div class="flex-1">
      <label class="mb-1 block text-sm font-heading">{@label}</label>
      <div
        id={@id}
        phx-hook="MultiSelect"
        data-options={@options_json}
        data-selected={@selected_json}
        data-event={@event}
        class="relative"
      >
        <div
          data-header
          tabindex="0"
          role="combobox"
          aria-expanded="false"
          aria-haspopup="listbox"
          class="flex flex-wrap items-center gap-1 min-h-[2.5rem] w-full rounded-base border-2 border-border bg-bw px-3 py-1.5 cursor-pointer"
        >
          <span data-tags class="flex flex-wrap gap-1"></span>
          <span data-placeholder class="text-sm text-fg/50 font-base">{@placeholder}</span>
          <span class="ml-auto pl-2">
            <svg class="w-4 h-4" viewBox="0 0 20 20" fill="currentColor">
              <path
                fill-rule="evenodd"
                d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
                clip-rule="evenodd"
              />
            </svg>
          </span>
        </div>
        <div
          data-dropdown
          role="listbox"
          class="hidden absolute top-full left-0 right-0 z-50 mt-1 rounded-base border-2 border-border bg-bw shadow-brutalist max-h-[40dvh] overflow-y-auto"
        >
          <div class="p-2 border-b-2 border-border">
            <input
              data-search
              type="text"
              placeholder="Search..."
              class="w-full rounded-base border-2 border-border bg-bw px-3 py-1.5 text-sm font-base placeholder:text-fg/50 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-1"
            />
          </div>
          <div data-options class="p-1"></div>
        </div>
      </div>
    </div>
    """
  end

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :params, :map, required: true

  defp pagination(assigns) do
    ~H"""
    <nav class="mt-8 flex justify-center gap-2" aria-label="Pagination">
      <.page_link :if={@page > 1} page={@page - 1} params={@params} label={gettext("Previous")} />

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
        label={gettext("Next")}
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
        "px-3 py-2 text-sm font-heading rounded-base border-2 border-border transition-all",
        @current && "bg-main shadow-brutalist",
        !@current && "bg-bw hover:bg-main"
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
    categories = Keyword.get(overrides, :categories, assigns.categories)
    mechanics = Keyword.get(overrides, :mechanics, assigns.mechanics)
    sort = Keyword.get(overrides, :sort, assigns.sort)
    sort_dir = Keyword.get(overrides, :sort_dir, assigns.sort_dir)

    params = %{
      "search" => Keyword.get(overrides, :search, assigns.search),
      "sort" => sort,
      "sort_dir" => sort_dir,
      "page" => Keyword.get(overrides, :page, assigns.page)
    }

    params =
      if categories != [],
        do: Map.put(params, "categories", Enum.join(categories, ",")),
        else: params

    params =
      if mechanics != [],
        do: Map.put(params, "mechanics", Enum.join(mechanics, ",")),
        else: params

    # Strip defaults to keep URLs clean
    params
    |> Enum.reject(fn
      {"sort_dir", dir} -> dir == default_dir(sort)
      {_k, v} -> v in ["", nil, 1, "rating"]
    end)
    |> Map.new()
  end

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end

  defp parse_list(nil), do: []
  defp parse_list(""), do: []
  defp parse_list(val) when is_binary(val), do: String.split(val, ",", trim: true)

  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_list(map, _key, []), do: map
  defp maybe_put_list(map, key, value), do: Map.put(map, key, value)

  defp default_dir("name"), do: "asc"
  defp default_dir(_), do: "desc"
end
