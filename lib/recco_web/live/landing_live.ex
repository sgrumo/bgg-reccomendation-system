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
      <h1 class="text-4xl sm:text-5xl font-bold text-zinc-900 mb-4">
        Discover your next<br />
        <span class="text-brand-600">favourite board game</span>
      </h1>
      <p class="text-lg text-zinc-600 max-w-xl mb-8">
        Browse thousands of board games, rate the ones you love,
        and get personalised recommendations powered by your taste.
      </p>
      <div class="flex flex-col sm:flex-row gap-3">
        <%= if @current_user do %>
          <a
            href={~p"/games"}
            class="rounded-lg bg-brand-600 px-6 py-3 text-sm font-semibold text-white hover:bg-brand-500"
          >
            Browse games
          </a>
        <% else %>
          <a
            href={~p"/register"}
            class="rounded-lg bg-brand-600 px-6 py-3 text-sm font-semibold text-white hover:bg-brand-500"
          >
            Get started
          </a>
          <a
            href={~p"/login"}
            class="rounded-lg border border-zinc-300 px-6 py-3 text-sm font-semibold text-zinc-700 hover:bg-zinc-50"
          >
            Sign in
          </a>
        <% end %>
      </div>
    </div>
    """
  end
end
