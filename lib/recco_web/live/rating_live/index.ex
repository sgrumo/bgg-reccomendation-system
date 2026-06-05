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
       page_title: gettext("My Ratings"),
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
    <div class="pb-12">
      <div class="label mb-2">{gettext("Your taste profile")}</div>
      <h1 class="text-[clamp(34px,4vw,58px)] mb-7">{gettext("My Ratings")}</h1>

      <div :if={@ratings == []} class="panel px-6 py-12 text-center">
        <p class="text-ink-soft text-[17px] mb-5">{gettext("You haven't rated any games yet.")}</p>
        <a href={~p"/games"} class="btn btn-primary">
          {gettext("Browse games to get started")} →
        </a>
      </div>

      <div class="space-y-3">
        <div
          :for={rating <- @ratings}
          class="panel flex items-center gap-4 p-4"
        >
          <div class="w-14 h-14 flex-shrink-0 border-bw border-line rounded-panel-sm bg-card2 overflow-hidden grid place-items-center">
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
              class="font-bold text-[17px] truncate block hover:underline"
            >
              {rating.board_game.name}
            </a>
            <p :if={rating.comment} class="text-ink-soft text-sm truncate">{rating.comment}</p>
          </div>
          <div class="font-mono font-bold text-lg bg-accent text-accent-ink border-2 border-line rounded-panel-sm px-3 py-1 shadow-panel-sm flex-shrink-0 tabular-nums">
            {Float.round(rating.score, 1)}
          </div>
          <button
            type="button"
            phx-click="delete_rating"
            phx-value-game-id={rating.board_game_id}
            class="btn btn-sm hover:!bg-danger hover:!text-accent-ink flex-shrink-0"
            data-confirm={gettext("Remove this rating?")}
          >
            {gettext("Remove")}
          </button>
        </div>
      </div>
    </div>
    """
  end
end
