defmodule ReccoWeb.LandingLive do
  use ReccoWeb, :live_view

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Board Game Recommendations")}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-[60vh] text-center px-4">
      <h1 class="text-4xl sm:text-5xl font-bold mb-4">
        Discover your next<br />
        <span class="inline-block rounded-base border-2 border-border bg-main px-3 py-1 shadow-brutalist mt-2">
          favourite board game
        </span>
      </h1>
      <p class="text-lg font-medium max-w-xl mb-8 mt-4">
        Browse thousands of board games, rate the ones you love,
        and get personalised recommendations powered by your taste.
      </p>
      <div class="flex flex-col sm:flex-row gap-3">
        <%= if @current_user do %>
          <a
            href={~p"/games"}
            class="rounded-base border-2 border-border bg-main px-6 py-3 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            Browse games
          </a>
        <% else %>
          <a
            href={~p"/register"}
            class="rounded-base border-2 border-border bg-main px-6 py-3 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            Get started
          </a>
          <a
            href={~p"/login"}
            class="rounded-base border-2 border-border bg-bw px-6 py-3 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            Sign in
          </a>
        <% end %>
      </div>
    </div>
    """
  end
end
