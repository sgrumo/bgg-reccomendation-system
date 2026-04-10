defmodule ReccoWeb.GameLive.Show do
  use ReccoWeb, :live_view

  alias Recco.BoardGames
  alias Recco.Ratings
  alias Recco.Recommender

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"id" => id}, _session, socket) do
    case BoardGames.get_board_game(id) do
      {:ok, game} ->
        user_rating = load_user_rating(socket.assigns[:current_user], game.id)

        socket =
          socket
          |> assign(
            page_title: game.name,
            game: game,
            user_rating: user_rating,
            rating_form_score: user_rating && user_rating.score,
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
      <a href={~p"/games"} class="text-sm text-brand-600 hover:underline mb-4 inline-block">
        &larr; Back to browse
      </a>

      <div class="flex flex-col md:flex-row gap-8">
        <div class="w-full md:w-1/3 lg:w-1/4 flex-shrink-0">
          <div class="aspect-square rounded-lg bg-zinc-100 overflow-hidden">
            <img
              :if={@game.image_url}
              src={@game.image_url}
              alt={@game.name}
              class="w-full h-full object-cover"
            />
          </div>
        </div>

        <div class="flex-1 min-w-0">
          <h1 class="text-3xl font-bold text-zinc-900">{@game.name}</h1>
          <p :if={@game.year_published} class="text-zinc-500 mt-1">
            {@game.year_published}
          </p>

          <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-6">
            <.stat label="Rating" value={format_rating(@game.average_rating)} />
            <.stat label="Weight" value={format_rating(@game.average_weight)} />
            <.stat label="Players" value={format_players(@game.min_players, @game.max_players)} />
            <.stat
              label="Time"
              value={format_playtime(@game.min_playtime, @game.max_playtime)}
            />
          </div>

          <.rating_widget
            current_user={@current_user}
            user_rating={@user_rating}
            rating_form_score={@rating_form_score}
          />

          <div :if={@game.description} class="mt-6">
            <h2 class="text-sm font-semibold text-zinc-700 mb-2">Description</h2>
            <p class="text-sm text-zinc-600 leading-relaxed">{@game.description}</p>
          </div>

          <div :if={@game.categories != []} class="mt-6">
            <h2 class="text-sm font-semibold text-zinc-700 mb-2">Categories</h2>
            <div class="flex flex-wrap gap-2">
              <span
                :for={cat <- @game.categories}
                class="inline-block rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-700"
              >
                {cat["value"]}
              </span>
            </div>
          </div>

          <div :if={@game.mechanics != []} class="mt-4">
            <h2 class="text-sm font-semibold text-zinc-700 mb-2">Mechanics</h2>
            <div class="flex flex-wrap gap-2">
              <span
                :for={mech <- @game.mechanics}
                class="inline-block rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-700"
              >
                {mech["value"]}
              </span>
            </div>
          </div>

          <div :if={@game.designers != []} class="mt-4">
            <h2 class="text-sm font-semibold text-zinc-700 mb-2">Designers</h2>
            <p class="text-sm text-zinc-600">
              {Enum.map_join(@game.designers, ", ", & &1["value"])}
            </p>
          </div>
        </div>
      </div>

      <div class="mt-10">
        <h2 class="text-xl font-bold text-zinc-900 mb-4">Similar Games</h2>

        <div :if={@similar_loading} class="grid grid-cols-2 sm:grid-cols-3 gap-4">
          <div :for={_ <- 1..6} class="animate-pulse rounded-lg border border-zinc-200 p-4">
            <div class="h-24 bg-zinc-200 rounded mb-2"></div>
            <div class="h-4 bg-zinc-200 rounded w-3/4"></div>
          </div>
        </div>

        <div
          :if={!@similar_loading && (@similar_games == nil || @similar_games == [])}
          class="text-sm text-zinc-500"
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
            class="block rounded-lg border border-zinc-200 hover:shadow-sm transition overflow-hidden"
          >
            <div class="aspect-[4/3] bg-zinc-100 flex items-center justify-center">
              <img
                :if={rec.game.image_url}
                src={rec.game.image_url}
                alt={rec.name}
                class="max-w-full max-h-full object-contain"
                loading="lazy"
              />
            </div>
            <div class="p-2">
              <p class="text-sm font-medium text-zinc-900 truncate">{rec.name}</p>
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
    <div class="mt-6 rounded-lg border border-zinc-200 p-4">
      <h2 class="text-sm font-semibold text-zinc-700 mb-3">Your Rating</h2>

      <%= if @current_user do %>
        <div class="flex items-center gap-4">
          <div class="flex gap-1">
            <button
              :for={score <- 1..10}
              phx-click="rate"
              phx-value-score={score}
              class={[
                "w-8 h-8 rounded text-sm font-medium transition",
                score_active?(score, @rating_form_score) &&
                  "bg-brand-600 text-white",
                !score_active?(score, @rating_form_score) &&
                  "bg-zinc-100 text-zinc-600 hover:bg-zinc-200"
              ]}
              aria-label={"Rate #{score} out of 10"}
            >
              {score}
            </button>
          </div>

          <button
            :if={@user_rating}
            phx-click="remove_rating"
            class="text-sm text-red-600 hover:text-red-800"
          >
            Remove
          </button>
        </div>

        <p :if={@user_rating} class="text-xs text-zinc-500 mt-2">
          You rated this {Float.round(@user_rating.score, 1)}/10
        </p>
      <% else %>
        <p class="text-sm text-zinc-500">
          <a href={~p"/login"} class="text-brand-600 hover:underline">Sign in</a> to rate this game.
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
    <div class="rounded-lg bg-zinc-50 p-3">
      <p class="text-xs text-zinc-500">{@label}</p>
      <p class="text-lg font-semibold text-zinc-900">{@value}</p>
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

  defp load_user_rating(nil, _game_id), do: nil
  defp load_user_rating(user, game_id), do: Ratings.get_user_rating(user.id, game_id)
end
