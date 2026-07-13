defmodule ReccoWeb.SearchLive do
  use ReccoWeb, :live_view

  alias Recco.Recommender
  alias Recco.Wishlists

  @limit 24

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       q: "",
       results: [],
       wishlisted: MapSet.new(),
       loading: false,
       searched: false,
       failed: false,
       page_title: gettext("Search")
     )}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    q = params["q"] || ""

    if String.trim(q) == "" do
      {:noreply,
       assign(socket,
         q: q,
         results: [],
         wishlisted: MapSet.new(),
         loading: false,
         searched: false,
         failed: false
       )}
    else
      {:noreply,
       socket
       |> assign(q: q, loading: true, searched: true, failed: false)
       |> start_async(:search, fn -> search_and_enrich(q) end)}
    end
  end

  defp search_and_enrich(query) do
    case Recommender.search(query, limit: @limit) do
      {:ok, recommendations} -> {:ok, Recommender.enrich_with_games(recommendations)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: ~p"/search?#{[q: q]}")}
  end

  def handle_event("add_to_wishlist", %{"game-id" => game_id}, socket) do
    user = socket.assigns.current_user

    cond do
      is_nil(user) ->
        {:noreply, socket}

      match?({:ok, _}, Wishlists.add_to_wishlist(user.id, game_id)) ->
        {:noreply, update(socket, :wishlisted, &MapSet.put(&1, game_id))}

      true ->
        {:noreply, put_flash(socket, :error, gettext("Could not add to wishlist"))}
    end
  end

  def handle_event("remove_from_wishlist", %{"game-id" => game_id}, socket) do
    user = socket.assigns.current_user

    if user do
      Wishlists.remove_from_wishlist(user.id, game_id)
      {:noreply, update(socket, :wishlisted, &MapSet.delete(&1, game_id))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  @spec handle_async(atom(), term(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_async(:search, {:ok, {:ok, results}}, socket) do
    wishlisted = load_wishlisted(socket.assigns.current_user, results)

    {:noreply,
     assign(socket, results: results, wishlisted: wishlisted, loading: false, failed: false)}
  end

  def handle_async(:search, {:ok, {:error, _reason}}, socket) do
    {:noreply, assign(socket, results: [], loading: false, failed: true)}
  end

  def handle_async(:search, {:exit, _reason}, socket) do
    {:noreply, assign(socket, results: [], loading: false, failed: true)}
  end

  defp load_wishlisted(nil, _results), do: MapSet.new()

  defp load_wishlisted(user, results) do
    result_ids =
      results
      |> Enum.map(& &1.game)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new(& &1.id)

    user.id
    |> Wishlists.list_user_wishlists()
    |> Enum.map(& &1.board_game_id)
    |> Enum.filter(&MapSet.member?(result_ids, &1))
    |> MapSet.new()
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="pb-12">
      <header class="mb-6">
        <div class="label mb-1.5">{gettext("Discover")}</div>
        <h1 class="text-[clamp(34px,4vw,58px)]">{gettext("Semantic Search")}</h1>
        <p class="text-ink-soft text-[17px] mt-2 max-w-[560px]">
          {gettext(
            "Describe the kind of game you want — a theme, a feel, a mechanic — and we'll find matches by meaning, not just by name."
          )}
        </p>
      </header>

      <form phx-submit="search" class="flex gap-2.5 max-w-[560px] mb-8">
        <div class="relative flex-1">
          <input
            type="text"
            name="q"
            value={@q}
            placeholder={gettext("e.g. cooperative deck building for two players")}
            class="field pr-12"
            autocomplete="off"
            aria-label={gettext("Search games by description")}
          />
          <span
            :if={@loading}
            class="spinner absolute right-4 top-[calc(50%-9px)]"
            aria-hidden="true"
          />
        </div>
        <button type="submit" class="btn btn-primary">
          {gettext("Search")}
        </button>
      </form>

      <div :if={@failed} class="panel px-6 py-12 text-center">
        <p class="text-ink-soft text-[17px]">
          {gettext("Search is temporarily unavailable. Please try again in a moment.")}
        </p>
      </div>

      <div
        :if={!@failed && @searched && !@loading && @results == []}
        class="panel px-6 py-12 text-center"
      >
        <p class="text-ink-soft text-[17px]">
          {gettext("No matches found. Try describing the game differently.")}
        </p>
      </div>

      <div
        :if={@results != []}
        class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5"
      >
        <.result_card
          :for={result <- @results}
          result={result}
          q={@q}
          current_user={@current_user}
          wishlisted={result.game && MapSet.member?(@wishlisted, result.game.id)}
        />
      </div>
    </div>
    """
  end

  attr :result, :map, required: true
  attr :q, :string, required: true
  attr :current_user, :any, required: true
  attr :wishlisted, :any, required: true

  defp result_card(%{result: %{game: nil}} = assigns) do
    ~H"""
    <article class="panel p-4 flex items-center justify-between gap-3">
      <h3 class="text-[19px] leading-[1.04]">{@result.name}</h3>
      <.match_badge score={@result.score} />
    </article>
    """
  end

  defp result_card(assigns) do
    ~H"""
    <article class="panel lift overflow-hidden flex flex-col relative">
      <.link navigate={~p"/games/#{@result.game.id}?#{[return_to: "search", q: @q]}"} class="block">
        <div class="aspect-[1.18/1] border-b-bw border-line bg-card2 grid place-items-center overflow-hidden">
          <img
            :if={@result.game.image_url}
            src={@result.game.image_url}
            alt={@result.game.name}
            class="max-w-full max-h-full object-contain"
            loading="lazy"
          />
        </div>
        <span class="absolute top-2.5 left-2.5">
          <.match_badge score={@result.score} />
        </span>
      </.link>

      <div class="absolute top-2.5 right-2.5 z-10">
        <.wishlist_toggle
          current_user={@current_user}
          wishlisted={@wishlisted}
          game_id={@result.game.id}
        />
      </div>

      <div class="p-3.5 flex flex-col gap-2 flex-1">
        <.link navigate={~p"/games/#{@result.game.id}?#{[return_to: "search", q: @q]}"} class="block">
          <div class="flex items-baseline justify-between gap-2">
            <h3 class="text-[21px] leading-[1.04]">{@result.game.name}</h3>
            <span
              :if={@result.game.year_published}
              class="font-mono text-ink-soft text-[13px] whitespace-nowrap pt-1"
            >
              {@result.game.year_published}
            </span>
          </div>
          <div class="flex flex-wrap items-center gap-3 mt-1.5 font-mono text-ink-soft text-[12.5px]">
            <span :if={@result.game.average_rating}>
              ★ {:erlang.float_to_binary(@result.game.average_rating, decimals: 1)}
            </span>
            <span :if={@result.game.min_players && @result.game.max_players}>
              {@result.game.min_players}–{@result.game.max_players}p
            </span>
            <span :if={@result.game.playing_time}>{@result.game.playing_time}m</span>
          </div>
        </.link>
      </div>
    </article>
    """
  end

  attr :current_user, :any, required: true
  attr :wishlisted, :any, required: true
  attr :game_id, :string, required: true

  defp wishlist_toggle(%{current_user: nil} = assigns) do
    ~H"""
    <a
      href={~p"/login"}
      class="btn btn-sm !p-2 !gap-0 bg-card"
      title={gettext("Sign in to wishlist")}
      aria-label={gettext("Sign in to wishlist")}
    >
      ♡
    </a>
    """
  end

  defp wishlist_toggle(%{wishlisted: true} = assigns) do
    ~H"""
    <button
      type="button"
      phx-click="remove_from_wishlist"
      phx-value-game-id={@game_id}
      class="btn btn-sm btn-primary !p-2 !gap-0"
      title={gettext("Remove from wishlist")}
      aria-label={gettext("Remove from wishlist")}
    >
      ♥
    </button>
    """
  end

  defp wishlist_toggle(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="add_to_wishlist"
      phx-value-game-id={@game_id}
      class="btn btn-sm !p-2 !gap-0 bg-card"
      title={gettext("Add to wishlist")}
      aria-label={gettext("Add to wishlist")}
    >
      ♡
    </button>
    """
  end

  attr :score, :float, required: true

  defp match_badge(assigns) do
    ~H"""
    <span
      class="font-mono font-bold text-[13px] bg-accent text-accent-ink border-2 border-line rounded-panel-sm px-2 py-0.5 shadow-panel-sm"
      style="transform: rotate(-5deg);"
      title={gettext("Match score")}
    >
      {round(@score * 100)}%
    </span>
    """
  end
end
