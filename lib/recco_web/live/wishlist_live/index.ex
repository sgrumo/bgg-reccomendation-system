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
       page_title: "My Wishlist",
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
    <div>
      <h1 class="text-2xl font-bold mb-6">My Wishlist</h1>

      <div
        :if={@wishlists == []}
        class="text-center py-16 rounded-base border-2 border-border bg-bw shadow-brutalist"
      >
        <p class="font-medium">Your wishlist is empty.</p>
        <a
          href={~p"/games"}
          class="mt-4 inline-block rounded-base border-2 border-border bg-main px-4 py-2 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
        >
          Browse games to find something you like
        </a>
      </div>

      <div class="space-y-3">
        <div
          :for={wishlist <- @wishlists}
          class="flex items-center gap-4 rounded-base border-2 border-border bg-bw p-4"
        >
          <div class="w-12 h-12 flex-shrink-0 rounded-base border-2 border-border bg-bg overflow-hidden">
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
              class="font-bold hover:bg-main truncate block"
            >
              {wishlist.board_game.name}
            </a>
            <p :if={wishlist.board_game.year_published} class="text-sm font-medium">
              {wishlist.board_game.year_published}
            </p>
          </div>
          <button
            phx-click="remove_from_wishlist"
            phx-value-game-id={wishlist.board_game_id}
            class="rounded-base border-2 border-border bg-red-300 px-3 py-1 text-sm font-bold hover:translate-x-[2px] hover:translate-y-[2px] transition-all flex-shrink-0"
            data-confirm="Remove from wishlist?"
          >
            Remove
          </button>
        </div>
      </div>
    </div>
    """
  end
end
