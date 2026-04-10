defmodule ReccoWeb.RatingLive.Index do
  use ReccoWeb, :live_view

  alias Recco.Ratings

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    ratings = Ratings.list_user_ratings(socket.assigns.current_user.id)

    {:ok,
     assign(socket,
       page_title: "My Ratings",
       ratings: ratings
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("delete_rating", %{"game-id" => game_id}, socket) do
    :ok = Ratings.delete_rating(socket.assigns.current_user.id, game_id)
    ratings = Ratings.list_user_ratings(socket.assigns.current_user.id)
    {:noreply, assign(socket, ratings: ratings)}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold text-zinc-900 mb-6">My Ratings</h1>

      <div :if={@ratings == []} class="text-center py-16 text-zinc-500">
        <p>You haven't rated any games yet.</p>
        <a href={~p"/games"} class="mt-4 inline-block text-brand-600 hover:underline">
          Browse games to get started
        </a>
      </div>

      <div class="space-y-3">
        <div
          :for={rating <- @ratings}
          class="flex items-center gap-4 rounded-lg border border-zinc-200 p-4"
        >
          <div class="w-12 h-12 flex-shrink-0 rounded bg-zinc-100 overflow-hidden">
            <img
              :if={rating.board_game.thumbnail_url}
              src={rating.board_game.thumbnail_url}
              alt={rating.board_game.name}
              class="w-full h-full object-cover"
            />
          </div>
          <div class="flex-1 min-w-0">
            <a
              href={~p"/games/#{rating.board_game_id}"}
              class="font-medium text-zinc-900 hover:underline truncate block"
            >
              {rating.board_game.name}
            </a>
            <p :if={rating.comment} class="text-sm text-zinc-500 truncate">{rating.comment}</p>
          </div>
          <div class="text-lg font-bold text-brand-600 flex-shrink-0">
            {Float.round(rating.score, 1)}
          </div>
          <button
            phx-click="delete_rating"
            phx-value-game-id={rating.board_game_id}
            class="text-sm text-red-600 hover:text-red-800 flex-shrink-0"
            data-confirm="Remove this rating?"
          >
            Remove
          </button>
        </div>
      </div>
    </div>
    """
  end
end
