defmodule ReccoWeb.GameLive.Index do
  use ReccoWeb, :live_view

  alias Recco.BoardGames
  alias Recco.Ratings

  @per_page 24
  @player_chips ~w(any 1 2 3-4 5plus)

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
    players = parse_players(params["players"])

    opts =
      %{page: page, per_page: @per_page, sort: sort}
      |> maybe_put(:search, search)
      |> maybe_put(:sort_dir, sort_dir)
      |> maybe_put_list(:categories, categories)
      |> maybe_put_list(:mechanics, mechanics)
      |> apply_players_opts(players)

    %{games: games, total: total} = BoardGames.list_board_games(opts)
    total_pages = max(ceil(total / @per_page), 1)
    user_scores = load_user_scores(socket.assigns[:current_user], games)

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
       sort_dir: sort_dir || default_dir(sort),
       players: players,
       user_scores: user_scores
     )}
  end

  defp load_user_scores(nil, _games), do: %{}

  defp load_user_scores(user, games) do
    Ratings.user_scores_map(user.id, Enum.map(games, & &1.id))
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

  def handle_event("set_players", %{"chip" => value}, socket) do
    params = build_params(socket.assigns, players: value, page: 1)
    {:noreply, push_patch(socket, to: ~p"/games?#{params}")}
  end

  def handle_event("clear_filters", _params, socket) do
    params =
      build_params(socket.assigns,
        categories: [],
        mechanics: [],
        players: "any",
        page: 1
      )

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

  def handle_event("rate", %{"game-id" => game_id, "score" => score_str}, socket) do
    user = socket.assigns[:current_user]

    if user do
      {score, _} = Float.parse(score_str)

      case Ratings.rate_game(user.id, game_id, %{score: score}) do
        {:ok, rating} ->
          {:noreply,
           assign(socket,
             user_scores: Map.put(socket.assigns.user_scores, game_id, rating.score)
           )}

        {:error, _, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not save rating"))}
      end
    else
      {:noreply, redirect(socket, to: ~p"/login")}
    end
  end

  def handle_event("clear_rating", %{"game-id" => game_id}, socket) do
    user = socket.assigns[:current_user]

    if user do
      _ = Ratings.delete_rating(user.id, game_id)
      {:noreply, assign(socket, user_scores: Map.delete(socket.assigns.user_scores, game_id))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="pb-12">
      <header class="flex flex-wrap items-end justify-between gap-4 mb-6">
        <div>
          <div class="label mb-1.5">{gettext("Catalogue")}</div>
          <h1 class="text-[clamp(34px,4vw,58px)]">{gettext("Browse Games")}</h1>
        </div>
        <form phx-change="search" phx-submit="search" class="w-full sm:w-[380px]">
          <input
            type="text"
            name="search"
            value={@search}
            placeholder={gettext("Search by title or designer…")}
            class="field"
            phx-debounce="300"
            aria-label={gettext("Search games")}
          />
        </form>
      </header>

      <div class="grid grid-cols-1 lg:grid-cols-[256px_1fr] gap-7 items-start">
        <aside class="lg:sticky lg:top-[90px] grid gap-4">
          <.sort_panel sort={@sort} sort_dir={@sort_dir} total={@total} />
          <.players_panel players={@players} />
          <.filter_panel
            id="category-filter"
            title={gettext("Categories")}
            event="filter_categories"
            placeholder={gettext("All categories")}
            options={@all_categories}
            selected={@categories}
          />
          <.filter_panel
            id="mechanic-filter"
            title={gettext("Mechanics")}
            event="filter_mechanics"
            placeholder={gettext("All mechanics")}
            options={@all_mechanics}
            selected={@mechanics}
          />
          <button
            :if={any_filter?(@categories, @mechanics, @players)}
            phx-click="clear_filters"
            class="btn btn-ghost btn-sm justify-center"
          >
            {gettext("Clear all filters")}
          </button>
        </aside>

        <div>
          <p class="label mb-3">
            {ngettext("%{count} game found", "%{count} games found", @total)}
          </p>

          <div
            :if={@games == []}
            class="panel px-6 py-12 text-center"
          >
            <p class="text-ink-soft text-[17px]">
              {gettext("No games found. Try a different search.")}
            </p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5">
            <.game_card
              :for={game <- @games}
              game={game}
              current_user={@current_user}
              user_score={Map.get(@user_scores, game.id)}
            />
          </div>

          <.pagination
            :if={@total_pages > 1}
            page={@page}
            total_pages={@total_pages}
            params={build_params(assigns)}
          />
        </div>
      </div>
    </div>
    """
  end

  ## ── filter rail panels ────────────────────────────────────────────────

  attr :sort, :string, required: true
  attr :sort_dir, :string, required: true
  attr :total, :integer, required: true

  defp sort_panel(assigns) do
    assigns =
      assign(assigns,
        options: [
          {"rating", gettext("Top rated")},
          {"name", gettext("Name")},
          {"year", gettext("Newest")},
          {"weight", gettext("Heaviest")}
        ]
      )

    ~H"""
    <div class="panel p-4">
      <div class="flex items-center justify-between mb-3.5">
        <span class="label label-ink !font-bold">{gettext("Sort")}</span>
        <button
          phx-click="toggle_sort_dir"
          class="label hover:text-ink"
          aria-label={gettext("Toggle sort direction")}
          title={if @sort_dir == "asc", do: gettext("Ascending"), else: gettext("Descending")}
        >
          {if @sort_dir == "asc", do: "↑", else: "↓"}
        </button>
      </div>
      <div class="grid gap-2">
        <button
          :for={{value, label} <- @options}
          phx-click="sort"
          phx-value-sort={value}
          class={[
            "btn btn-sm justify-start",
            @sort == value && "btn-primary",
            @sort != value && "btn-ghost"
          ]}
          aria-pressed={@sort == value}
        >
          {label}
        </button>
      </div>
    </div>
    """
  end

  attr :players, :string, required: true

  defp players_panel(assigns) do
    assigns = assign(assigns, :chips, player_chip_labels())

    ~H"""
    <div class="panel p-4">
      <span class="label label-ink !font-bold block mb-3">{gettext("Players")}</span>
      <div class="flex flex-wrap gap-1.5">
        <button
          :for={{chip_value, label} <- @chips}
          type="button"
          phx-click="set_players"
          phx-value-chip={chip_value}
          class={[
            "chip cursor-pointer",
            @players == chip_value && "chip-accent"
          ]}
          aria-pressed={@players == chip_value}
        >
          {label}
        </button>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :event, :string, required: true
  attr :placeholder, :string, required: true
  attr :options, :list, required: true
  attr :selected, :list, required: true

  defp filter_panel(assigns) do
    options_json = Jason.encode!(Enum.map(assigns.options, &%{name: &1.name}))
    selected_json = Jason.encode!(assigns.selected)
    assigns = assign(assigns, options_json: options_json, selected_json: selected_json)

    ~H"""
    <div class="panel p-4">
      <span class="label label-ink !font-bold block mb-3">{@title}</span>
      <div
        id={@id}
        phx-hook="MultiSelect"
        data-options={@options_json}
        data-selected={@selected_json}
        data-event={@event}
        class="ms"
      >
        <div
          data-header
          tabindex="0"
          role="combobox"
          aria-expanded="false"
          aria-haspopup="listbox"
          class="ms-trigger"
        >
          <span data-tags class="flex flex-wrap gap-1.5 items-center"></span>
          <span data-placeholder class="text-ink-soft text-sm">{@placeholder}</span>
          <span class="font-mono text-xs opacity-70 ml-auto">▼</span>
        </div>
        <div
          data-dropdown
          role="listbox"
          class="ms-pop hidden"
        >
          <div class="p-1.5 border-b-bw border-line">
            <input
              data-search
              type="text"
              placeholder={gettext("Search…")}
              class="w-full px-2.5 py-1.5 text-sm font-medium bg-card border-2 border-line rounded-panel-sm text-ink placeholder:text-ink-soft focus:outline-none"
            />
          </div>
          <div data-options></div>
        </div>
      </div>

      <div :if={@selected != []} class="flex flex-wrap gap-1.5 mt-3">
        <button
          :for={item <- @selected}
          phx-click={@event}
          phx-value-selected={Jason.encode!(Enum.reject(@selected, &(&1 == item)))}
          class="chip chip-accent cursor-pointer text-xs"
        >
          {item} <span class="ml-1 font-extrabold">×</span>
        </button>
      </div>
    </div>
    """
  end

  ## ── card ──────────────────────────────────────────────────────────────

  attr :game, :map, required: true
  attr :current_user, :any, required: true
  attr :user_score, :any, required: true

  defp game_card(assigns) do
    ~H"""
    <article class="panel lift overflow-hidden flex flex-col">
      <.link patch={~p"/games/#{@game.id}"} class="block relative">
        <div class="aspect-[1.18/1] border-b-bw border-line bg-card2 grid place-items-center overflow-hidden">
          <img
            :if={@game.image_url}
            src={@game.image_url}
            alt={@game.name}
            class="max-w-full max-h-full object-contain"
            loading="lazy"
          />
        </div>
        <span
          :if={@user_score && @user_score > 0}
          class="absolute top-2.5 right-2.5 font-mono font-bold text-[13px] bg-accent text-accent-ink border-2 border-line rounded-panel-sm px-2 py-0.5 shadow-panel-sm"
          style="transform: rotate(5deg);"
        >
          ★ {trunc(@user_score)}/10
        </span>
      </.link>

      <div class="p-3.5 flex flex-col gap-2.5 flex-1">
        <.link patch={~p"/games/#{@game.id}"} class="block">
          <div class="flex items-baseline justify-between gap-2">
            <h3 class="text-[21px] leading-[1.04]">{@game.name}</h3>
            <span
              :if={@game.year_published}
              class="font-mono text-ink-soft text-[13px] whitespace-nowrap pt-1"
            >
              {@game.year_published}
            </span>
          </div>
          <div class="flex flex-wrap items-center gap-3 mt-1.5 font-mono text-ink-soft text-[12.5px]">
            <span :if={@game.average_rating}>★ {format_rating(@game)}</span>
            <span :if={@game.min_players && @game.max_players}>
              {players_label(@game)}
            </span>
            <span :if={@game.playing_time}>{@game.playing_time}m</span>
          </div>
        </.link>

        <div class="mt-auto pt-1">
          <div class="flex items-center justify-between gap-2 mb-1.5 min-h-[28px]">
            <span class="label !text-[10.5px]">
              {if @user_score, do: gettext("Your rating"), else: gettext("Rate this")}
            </span>
            <button
              :if={@user_score}
              type="button"
              phx-click="clear_rating"
              phx-value-game-id={@game.id}
              class="btn btn-ghost btn-sm !py-1 !px-2.5 !gap-1.5 !text-[12px] !font-bold hover:!bg-danger hover:!text-accent-ink"
              aria-label={gettext("Clear rating")}
              title={gettext("Clear rating")}
            >
              <span aria-hidden="true" class="text-base leading-none">×</span>
              {gettext("Clear")}
            </button>
          </div>
          <form phx-change="rate" class="flex items-center gap-3">
            <input type="hidden" name="game-id" value={@game.id} />
            <input
              type="range"
              name="score"
              min="1"
              max="10"
              step="1"
              value={slider_value(@user_score)}
              phx-debounce="250"
              data-unrated={if @user_score, do: "false", else: "true"}
              class="rate-slider flex-1"
              aria-label={gettext("Rate %{game} out of 10", game: @game.name)}
              aria-valuenow={trunc(@user_score || 0)}
            />
            <span class={[
              "font-mono font-bold text-sm tabular-nums min-w-[44px] text-right",
              !@user_score && "text-ink-soft"
            ]}>
              {if @user_score, do: "#{trunc(@user_score)}/10", else: "—/10"}
            </span>
          </form>
        </div>
      </div>
    </article>
    """
  end

  # Slider always needs an integer value attribute (1..10). For unrated
  # games we surface 5 as a neutral resting position, paired with
  # data-unrated="true" so the thumb renders muted in CSS until the user
  # interacts.
  defp slider_value(nil), do: 5
  defp slider_value(score) when is_number(score), do: trunc(score)

  ## ── pagination ────────────────────────────────────────────────────────

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :params, :map, required: true

  defp pagination(assigns) do
    ~H"""
    <nav class="mt-8 flex justify-center gap-2 flex-wrap" aria-label="Pagination">
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
        "btn btn-sm",
        @current && "btn-primary",
        !@current && "btn-ghost"
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

  ## ── params helpers ────────────────────────────────────────────────────

  defp build_params(assigns, overrides \\ []) do
    categories = Keyword.get(overrides, :categories, assigns.categories)
    mechanics = Keyword.get(overrides, :mechanics, assigns.mechanics)
    sort = Keyword.get(overrides, :sort, assigns.sort)
    sort_dir = Keyword.get(overrides, :sort_dir, assigns.sort_dir)
    players = Keyword.get(overrides, :players, assigns.players)

    params = %{
      "search" => Keyword.get(overrides, :search, assigns.search),
      "sort" => sort,
      "sort_dir" => sort_dir,
      "page" => Keyword.get(overrides, :page, assigns.page),
      "players" => players
    }

    params =
      if categories != [],
        do: Map.put(params, "categories", Enum.join(categories, ",")),
        else: params

    params =
      if mechanics != [],
        do: Map.put(params, "mechanics", Enum.join(mechanics, ",")),
        else: params

    params
    |> Enum.reject(fn
      {"sort_dir", dir} -> dir == default_dir(sort)
      {"players", p} -> p in [nil, "any"]
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

  defp parse_players(val) when val in @player_chips, do: val
  defp parse_players(_), do: "any"

  defp apply_players_opts(opts, "any"), do: opts
  defp apply_players_opts(opts, "1"), do: Map.merge(opts, %{min_players: 1, max_players: 1})
  defp apply_players_opts(opts, "2"), do: Map.merge(opts, %{min_players: 2, max_players: 2})
  defp apply_players_opts(opts, "3-4"), do: Map.merge(opts, %{min_players: 3, max_players: 4})
  defp apply_players_opts(opts, "5plus"), do: Map.put(opts, :min_players, 5)
  defp apply_players_opts(opts, _), do: opts

  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_list(map, _key, []), do: map
  defp maybe_put_list(map, key, value), do: Map.put(map, key, value)

  defp default_dir("name"), do: "asc"
  defp default_dir(_), do: "desc"

  defp any_filter?(categories, mechanics, players),
    do: categories != [] or mechanics != [] or players != "any"

  defp format_rating(%{bayes_average_rating: r}) when is_float(r),
    do: :erlang.float_to_binary(r, decimals: 1)

  defp format_rating(%{average_rating: r}) when is_float(r),
    do: :erlang.float_to_binary(r, decimals: 1)

  defp format_rating(_), do: "—"

  defp players_label(%{min_players: a, max_players: b}) when a == b,
    do: "#{a} #{gettext("players")}"

  defp players_label(%{min_players: a, max_players: b}), do: "#{a}–#{b} #{gettext("players")}"

  defp player_chip_labels do
    [
      {"any", gettext("Any")},
      {"1", "1"},
      {"2", "2"},
      {"3-4", "3–4"},
      {"5plus", "5+"}
    ]
  end
end
