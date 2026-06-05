defmodule ReccoWeb.WishlistLive.Index do
  use ReccoWeb, :live_view

  alias Recco.Wishlists

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    wishlists = Wishlists.list_user_wishlists(socket.assigns.current_user.id)

    {:ok,
     assign(socket,
       page_title: gettext("My Wishlist"),
       wishlists: wishlists
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("remove_from_wishlist", %{"game-id" => game_id}, socket) do
    :ok = Wishlists.remove_from_wishlist(socket.assigns.current_user.id, game_id)
    wishlists = Wishlists.list_user_wishlists(socket.assigns.current_user.id)
    {:noreply, assign(socket, wishlists: wishlists)}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="pb-12">
      <div class="label mb-2">{gettext("Saved for later")}</div>
      <h1 class="text-[clamp(34px,4vw,58px)] mb-7">{gettext("My Wishlist")}</h1>

      <div :if={@wishlists == []} class="panel px-6 py-12 text-center">
        <p class="text-ink-soft text-[17px] mb-5">{gettext("Your wishlist is empty.")}</p>
        <a href={~p"/games"} class="btn btn-primary">
          {gettext("Browse games to find something you like")} →
        </a>
      </div>

      <div class="space-y-3">
        <div
          :for={wishlist <- @wishlists}
          class="panel flex items-center gap-4 p-4"
        >
          <div class="w-14 h-14 flex-shrink-0 border-bw border-line rounded-panel-sm bg-card2 overflow-hidden grid place-items-center">
            <img
              :if={wishlist.board_game.thumbnail_url}
              src={wishlist.board_game.thumbnail_url}
              alt={wishlist.board_game.name}
              class="w-full h-full object-cover"
            />
          </div>
          <div class="flex-1 min-w-0">
            <a
              href={~p"/games/#{wishlist.board_game_id}"}
              class="font-bold text-[17px] truncate block hover:underline"
            >
              {wishlist.board_game.name}
            </a>
            <p :if={wishlist.board_game.year_published} class="font-mono text-ink-soft text-[13px]">
              {wishlist.board_game.year_published}
            </p>
          </div>
          <button
            type="button"
            phx-click="remove_from_wishlist"
            phx-value-game-id={wishlist.board_game_id}
            class="btn btn-sm hover:!bg-danger hover:!text-accent-ink flex-shrink-0"
            data-confirm={gettext("Remove from wishlist?")}
          >
            {gettext("Remove")}
          </button>
        </div>
      </div>
    </div>
    """
  end
end
