defmodule ReccoWeb.GameLive.Show do
  use ReccoWeb, :live_view

  alias Recco.BoardGames
  alias Recco.Ratings
  alias Recco.Recommender
  alias Recco.Wishlists

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"id" => id}, _session, socket) do
    case BoardGames.get_board_game(id) do
      {:ok, game} ->
        user_rating = load_user_rating(socket.assigns[:current_user], game.id)
        wishlisted = load_wishlisted(socket.assigns[:current_user], game.id)

        socket =
          socket
          |> assign(
            page_title: game.name,
            game: game,
            user_rating: user_rating,
            rating_form_score: user_rating && user_rating.score,
            wishlisted: wishlisted,
            similar_games: nil,
            similar_loading: true
          )
          |> start_async(:fetch_similar, fn ->
            Recommender.game_recommendations(game.bgg_id, top_n: 6)
          end)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Game not found")
         |> redirect(to: ~p"/games")}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("rate", %{"score" => score_str}, socket) do
    user = socket.assigns.current_user

    if user do
      {score, _} = Float.parse(score_str)

      case Ratings.rate_game(user.id, socket.assigns.game.id, %{score: score}) do
        {:ok, rating} ->
          {:noreply, assign(socket, user_rating: rating, rating_form_score: rating.score)}

        {:error, _, _} ->
          {:noreply, put_flash(socket, :error, "Could not save rating")}
      end
    else
      {:noreply, redirect(socket, to: ~p"/login")}
    end
  end

  def handle_event("remove_rating", _params, socket) do
    user = socket.assigns.current_user

    if user && socket.assigns.user_rating do
      :ok = Ratings.delete_rating(user.id, socket.assigns.game.id)
      {:noreply, assign(socket, user_rating: nil, rating_form_score: nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("add_to_wishlist", _params, socket) do
    user = socket.assigns.current_user

    if user do
      case Wishlists.add_to_wishlist(user.id, socket.assigns.game.id) do
        {:ok, _} ->
          {:noreply, assign(socket, wishlisted: true)}

        {:error, _, _} ->
          {:noreply, put_flash(socket, :error, "Could not add to wishlist")}
      end
    else
      {:noreply, redirect(socket, to: ~p"/login")}
    end
  end

  def handle_event("remove_from_wishlist", _params, socket) do
    user = socket.assigns.current_user

    if user && socket.assigns.wishlisted do
      :ok = Wishlists.remove_from_wishlist(user.id, socket.assigns.game.id)
      {:noreply, assign(socket, wishlisted: false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  @spec handle_async(atom(), {:ok, term()} | {:exit, term()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_async(:fetch_similar, {:ok, {:ok, recs}}, socket) do
    enriched = Recommender.enrich_with_games(recs)
    {:noreply, assign(socket, similar_games: enriched, similar_loading: false)}
  end

  def handle_async(:fetch_similar, _result, socket) do
    {:noreply, assign(socket, similar_games: nil, similar_loading: false)}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <a
        href={~p"/games"}
        class="text-sm font-bold underline decoration-2 underline-offset-2 hover:bg-main mb-4 inline-block"
      >
        &larr; Back to browse
      </a>

      <div class="flex flex-col md:flex-row gap-8">
        <div class="w-full md:w-1/3 lg:w-1/4 flex-shrink-0">
          <div class="aspect-square rounded-base border-2 border-border bg-bw overflow-hidden shadow-brutalist flex items-center justify-center">
            <img
              :if={@game.image_url}
              src={@game.image_url}
              alt={@game.name}
              class="max-w-full max-h-full object-contain"
            />
          </div>
        </div>

        <div class="flex-1 min-w-0">
          <h1 class="text-3xl font-bold">{@game.name}</h1>
          <p :if={@game.year_published} class="font-medium mt-1">
            {@game.year_published}
          </p>

          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-6">
            <.stat label="Rating" value={format_rating(@game.average_rating)} />
            <.stat label="Weight" value={format_rating(@game.average_weight)} />
            <.stat label="Players" value={format_players(@game.min_players, @game.max_players)} />
            <.stat label="Time" value={format_playtime(@game.min_playtime, @game.max_playtime)} />
          </div>

          <.rating_widget
            current_user={@current_user}
            user_rating={@user_rating}
            rating_form_score={@rating_form_score}
          />

          <.wishlist_widget current_user={@current_user} wishlisted={@wishlisted} />

          <div :if={@game.description} class="mt-6 rounded-base border-2 border-border bg-bw p-4">
            <h2 class="text-sm font-bold mb-2">Description</h2>
            <p class="text-sm font-medium leading-relaxed">{@game.description}</p>
          </div>

          <div :if={@game.categories != []} class="mt-4">
            <h2 class="text-sm font-bold mb-2">Categories</h2>
            <div class="flex flex-wrap gap-2">
              <span
                :for={cat <- @game.categories}
                class="inline-block rounded-base border-2 border-border bg-main px-2.5 py-0.5 text-xs font-bold"
              >
                {cat["value"]}
              </span>
            </div>
          </div>

          <div :if={@game.mechanics != []} class="mt-4">
            <h2 class="text-sm font-bold mb-2">Mechanics</h2>
            <div class="flex flex-wrap gap-2">
              <span
                :for={mech <- @game.mechanics}
                class="inline-block rounded-base border-2 border-border bg-bw px-2.5 py-0.5 text-xs font-bold"
              >
                {mech["value"]}
              </span>
            </div>
          </div>

          <div :if={@game.designers != []} class="mt-4">
            <h2 class="text-sm font-bold mb-2">Designers</h2>
            <p class="text-sm font-medium">
              {Enum.map_join(@game.designers, ", ", & &1["value"])}
            </p>
          </div>
        </div>
      </div>

      <div class="mt-10">
        <h2 class="text-xl font-bold mb-4">Similar Games</h2>

        <div :if={@similar_loading} class="grid grid-cols-2 sm:grid-cols-3 gap-4">
          <div :for={_ <- 1..6} class="rounded-base border-2 border-border bg-bw p-4">
            <div class="h-24 bg-bg rounded-base mb-2 animate-pulse"></div>
            <div class="h-4 bg-bg rounded-base w-3/4 animate-pulse"></div>
          </div>
        </div>

        <div
          :if={!@similar_loading && (@similar_games == nil || @similar_games == [])}
          class="text-sm font-medium"
        >
          No similar games found.
        </div>

        <div
          :if={!@similar_loading && @similar_games && @similar_games != []}
          class="grid grid-cols-2 sm:grid-cols-3 gap-4"
        >
          <a
            :for={rec <- @similar_games}
            :if={rec.game}
            href={~p"/games/#{rec.game.id}"}
            class="block rounded-base border-2 border-border bg-bw shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all overflow-hidden"
          >
            <div class="aspect-[4/3] bg-bg flex items-center justify-center border-b-2 border-border">
              <img
                :if={rec.game.image_url}
                src={rec.game.image_url}
                alt={rec.name}
                class="max-w-full max-h-full object-contain"
                loading="lazy"
              />
            </div>
            <div class="p-2">
              <p class="text-sm font-bold truncate">{rec.name}</p>
            </div>
          </a>
        </div>
      </div>
    </div>
    """
  end

  attr :current_user, :any, required: true
  attr :user_rating, :any, required: true
  attr :rating_form_score, :any, required: true

  defp rating_widget(assigns) do
    ~H"""
    <div class="mt-6 rounded-base border-2 border-border bg-bw p-4 shadow-brutalist">
      <h2 class="text-sm font-bold mb-3">Your Rating</h2>

      <%= if @current_user do %>
        <div class="flex items-center gap-4">
          <div class="flex gap-1">
            <button
              :for={score <- 1..10}
              phx-click="rate"
              phx-value-score={score}
              class={[
                "w-8 h-8 rounded-base border-2 border-border text-sm font-bold transition-all",
                score_active?(score, @rating_form_score) && "bg-main",
                !score_active?(score, @rating_form_score) && "bg-bw hover:bg-bg"
              ]}
              aria-label={"Rate #{score} out of 10"}
            >
              {score}
            </button>
          </div>

          <button
            :if={@user_rating}
            phx-click="remove_rating"
            class="rounded-base border-2 border-border bg-red-300 px-3 py-1 text-sm font-bold hover:translate-x-[2px] hover:translate-y-[2px] transition-all"
          >
            Remove
          </button>
        </div>

        <p :if={@user_rating} class="text-xs font-medium mt-2">
          You rated this {Float.round(@user_rating.score, 1)}/10
        </p>
      <% else %>
        <p class="text-sm font-medium">
          <a
            href={~p"/login"}
            class="font-bold underline decoration-2 underline-offset-2 hover:bg-main"
          >
            Sign in
          </a>
          to rate this game.
        </p>
      <% end %>
    </div>
    """
  end

  defp score_active?(_score, nil), do: false
  defp score_active?(score, current) when is_number(current), do: score <= round(current)

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp stat(assigns) do
    ~H"""
    <div class="rounded-base border-2 border-border bg-bw p-3">
      <p class="text-xs font-bold">{@label}</p>
      <p class="text-lg font-bold">{@value}</p>
    </div>
    """
  end

  defp format_rating(nil), do: "N/A"
  defp format_rating(val), do: :erlang.float_to_binary(val / 1, decimals: 1)

  defp format_players(nil, nil), do: "N/A"
  defp format_players(min, max) when min == max, do: "#{min}"
  defp format_players(min, max), do: "#{min}-#{max}"

  defp format_playtime(nil, nil), do: "N/A"
  defp format_playtime(min, max) when min == max, do: "#{min}m"
  defp format_playtime(min, max), do: "#{min}-#{max}m"

  attr :current_user, :any, required: true
  attr :wishlisted, :boolean, required: true

  defp wishlist_widget(assigns) do
    ~H"""
    <div class="mt-4 flex items-center gap-3">
      <%= if @current_user do %>
        <%= if @wishlisted do %>
          <button
            phx-click="remove_from_wishlist"
            class="rounded-base border-2 border-border bg-main px-4 py-2 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            Remove from wishlist
          </button>
        <% else %>
          <button
            phx-click="add_to_wishlist"
            class="rounded-base border-2 border-border bg-bw px-4 py-2 text-sm font-bold hover:bg-bg transition-colors"
          >
            Add to wishlist
          </button>
        <% end %>
      <% else %>
        <p class="text-sm font-medium">
          <a
            href={~p"/login"}
            class="font-bold underline decoration-2 underline-offset-2 hover:bg-main"
          >
            Sign in
          </a>
          to add to your wishlist.
        </p>
      <% end %>
    </div>
    """
  end

  defp load_user_rating(nil, _game_id), do: nil
  defp load_user_rating(user, game_id), do: Ratings.get_user_rating(user.id, game_id)

  defp load_wishlisted(nil, _game_id), do: false
  defp load_wishlisted(user, game_id), do: Wishlists.wishlisted?(user.id, game_id)
end
