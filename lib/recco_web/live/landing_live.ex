defmodule ReccoWeb.LandingLive do
  use ReccoWeb, :live_view

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Board Game Recommendations"))}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-[60vh] text-center px-4">
      <h1 class="text-4xl sm:text-5xl font-bold mb-4">
        {gettext("Discover your next")}<br />
        <span class="inline-block rounded-base border-2 border-border bg-main px-3 py-1 shadow-brutalist mt-2">
          {gettext("favourite board game")}
        </span>
      </h1>
      <p class="text-lg font-medium max-w-xl mb-8 mt-4">
        {gettext(
          "Browse thousands of board games, rate the ones you love, and get personalised recommendations powered by your taste."
        )}
      </p>
      <div class="flex flex-col sm:flex-row gap-3">
        <%= if @current_user do %>
          <a
            href={~p"/games"}
            class="rounded-base border-2 border-border bg-main px-6 py-3 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            {gettext("Browse games")}
          </a>
        <% else %>
          <a
            href={~p"/register"}
            class="rounded-base border-2 border-border bg-main px-6 py-3 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            {gettext("Get started")}
          </a>
          <a
            href={~p"/login"}
            class="rounded-base border-2 border-border bg-bw px-6 py-3 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            {gettext("Sign in")}
          </a>
        <% end %>
      </div>
    </div>

    <div
      :if={@current_user && !@current_user.bgg_username}
      class="max-w-2xl mx-auto px-4 mt-12"
    >
      <div class="rounded-base border-2 border-border bg-bw p-6 shadow-brutalist text-center">
        <h2 class="text-lg font-bold mb-2">{gettext("Already rate games on BoardGameGeek?")}</h2>
        <p class="text-sm mb-4">
          {gettext("Link your BGG account to import your ratings and get personalised recommendations right away.")}
        </p>
        <a
          href={~p"/profile"}
          class="inline-block rounded-base border-2 border-border bg-main px-5 py-2.5 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
        >
          {gettext("Link BGG account")}
        </a>
      </div>
    </div>

    <div class="max-w-5xl mx-auto px-4 py-16">
      <h2 class="text-2xl sm:text-3xl font-bold text-center mb-12">
        {gettext("How it works")}
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="rounded-base border-2 border-border bg-bw p-6 shadow-brutalist">
          <div class="rounded-base border-2 border-border bg-main w-12 h-12 flex items-center justify-center mb-4 text-xl font-bold">
            1
          </div>
          <h3 class="text-lg font-bold mb-2">{gettext("Browse & explore")}</h3>
          <p class="text-sm">
            {gettext(
              "Search through thousands of board games sourced from BoardGameGeek. Filter by category, mechanics, player count, and more to find games that catch your eye."
            )}
          </p>
        </div>
        <div class="rounded-base border-2 border-border bg-bw p-6 shadow-brutalist">
          <div class="rounded-base border-2 border-border bg-main w-12 h-12 flex items-center justify-center mb-4 text-xl font-bold">
            2
          </div>
          <h3 class="text-lg font-bold mb-2">{gettext("Rate your games")}</h3>
          <p class="text-sm">
            {gettext(
              "Rate the board games you've played on a 1-to-10 scale. The more games you rate, the better the system understands your preferences and taste."
            )}
          </p>
        </div>
        <div class="rounded-base border-2 border-border bg-bw p-6 shadow-brutalist">
          <div class="rounded-base border-2 border-border bg-main w-12 h-12 flex items-center justify-center mb-4 text-xl font-bold">
            3
          </div>
          <h3 class="text-lg font-bold mb-2">{gettext("Get recommendations")}</h3>
          <p class="text-sm">
            {gettext(
              "Our engine analyses game features — categories, mechanics, complexity, and more — then uses content-based similarity to find games you'll love based on your unique rating profile."
            )}
          </p>
        </div>
      </div>
    </div>
    """
  end
end
