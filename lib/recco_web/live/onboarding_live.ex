defmodule ReccoWeb.OnboardingLive do
  use ReccoWeb, :live_view

  alias Recco.Accounts
  alias Recco.BoardGames
  alias Recco.Ratings

  @onboarding_size 12
  @search_size 24
  @ratings_threshold 5

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user.onboarded_at do
      {:ok, redirect(socket, to: ~p"/")}
    else
      games = BoardGames.list_onboarding_picks(@onboarding_size)
      user_scores = Ratings.user_scores_map(user.id, Enum.map(games, & &1.id))

      {:ok,
       assign(socket,
         page_title: gettext("Welcome"),
         search: "",
         games: games,
         user_scores: user_scores,
         dismissed: MapSet.new(),
         ratings_threshold: @ratings_threshold
       )}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("rate", %{"game-id" => game_id, "score" => score_str}, socket) do
    user = socket.assigns.current_user
    {score, _} = Float.parse(score_str)

    case Ratings.rate_game(user.id, game_id, %{score: score}) do
      {:ok, rating} ->
        {:noreply,
         assign(socket,
           user_scores: Map.put(socket.assigns.user_scores, game_id, rating.score)
         )}

      {:error, _, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save rating"))}
    end
  end

  def handle_event("clear_rating", %{"game-id" => game_id}, socket) do
    _ = Ratings.delete_rating(socket.assigns.current_user.id, game_id)
    {:noreply, assign(socket, user_scores: Map.delete(socket.assigns.user_scores, game_id))}
  end

  def handle_event("dismiss", %{"game-id" => game_id}, socket) do
    {:noreply, assign(socket, dismissed: MapSet.put(socket.assigns.dismissed, game_id))}
  end

  def handle_event("finish", _params, socket) do
    {:ok, _} = Accounts.mark_onboarded(socket.assigns.current_user)

    target =
      if map_size(socket.assigns.user_scores) > 0 do
        ~p"/recommendations"
      else
        ~p"/games"
      end

    {:noreply, redirect(socket, to: target)}
  end

  def handle_event("skip", _params, socket) do
    {:ok, _} = Accounts.mark_onboarded(socket.assigns.current_user)
    {:noreply, redirect(socket, to: ~p"/")}
  end

  def handle_event("search", %{"search" => search}, socket) do
    user = socket.assigns.current_user
    search = String.trim(search)

    games =
      if search == "" do
        BoardGames.list_onboarding_picks(@onboarding_size)
      else
        %{games: games} =
          BoardGames.list_board_games(%{
            search: search,
            per_page: @search_size,
            sort: "rating"
          })

        games
      end

    merged_scores =
      Map.merge(
        socket.assigns.user_scores,
        Ratings.user_scores_map(user.id, Enum.map(games, & &1.id))
      )

    {:noreply,
     assign(socket,
       search: search,
       games: games,
       user_scores: merged_scores
     )}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    rated_count = map_size(assigns.user_scores)
    assigns = assign(assigns, rated_count: rated_count)

    ~H"""
    <div class="max-w-5xl mx-auto">
      <div class="text-center mb-6">
        <h1 class="text-3xl font-bold">{gettext("Welcome! Tell us what you like")}</h1>
        <p class="text-sm font-medium mt-2 max-w-xl mx-auto">
          {gettext(
            "Rate any games you've played below. Even 3-5 ratings are enough to start getting personalised picks — the more you rate, the sharper they get."
          )}
        </p>
      </div>

      <.progress_banner rated_count={@rated_count} ratings_threshold={@ratings_threshold} />

      <form phx-change="search" phx-submit="search" class="mb-6">
        <.input
          name="search"
          type="text"
          value={@search}
          placeholder={gettext("Search for a game you've played...")}
          phx-debounce="300"
        />
      </form>

      <p :if={@search != ""} class="text-xs font-medium mb-3">
        {if @games == [],
          do: gettext("No games match \"%{search}\".", search: @search),
          else: gettext("Showing results for \"%{search}\".", search: @search)}
      </p>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
        <.onboarding_card
          :for={game <- @games}
          :if={not MapSet.member?(@dismissed, game.id)}
          game={game}
          score={Map.get(@user_scores, game.id)}
        />
      </div>

      <div class="mt-8 flex items-center justify-between gap-3 flex-wrap">
        <button
          phx-click="skip"
          class="text-sm font-bold underline decoration-2 underline-offset-2 hover:bg-main px-1"
        >
          {gettext("Skip for now")}
        </button>
        <button
          phx-click="finish"
          class="rounded-base border-2 border-border bg-main px-5 py-2.5 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
        >
          {if @rated_count > 0,
            do: gettext("I'm done — show my picks") <> " →",
            else: gettext("I'm done") <> " →"}
        </button>
      </div>
    </div>
    """
  end

  attr :rated_count, :integer, required: true
  attr :ratings_threshold, :integer, required: true

  defp progress_banner(assigns) do
    remaining = max(assigns.ratings_threshold - assigns.rated_count, 0)
    pct = min(round(assigns.rated_count / assigns.ratings_threshold * 100), 100)
    assigns = assign(assigns, remaining: remaining, pct: pct)

    ~H"""
    <div class="mb-6 rounded-base border-2 border-border bg-main/30 p-4 shadow-brutalist">
      <div class="flex items-center justify-between gap-3 flex-wrap">
        <p class="text-sm font-bold">
          <%= if @remaining == 0 do %>
            {gettext("%{count} rated — you're ready for recommendations.",
              count: @rated_count
            )}
          <% else %>
            {gettext("%{count} of %{total} rated",
              count: @rated_count,
              total: @ratings_threshold
            )}
          <% end %>
        </p>
        <p :if={@remaining > 0} class="text-xs font-medium">
          {ngettext(
            "Rate %{count} more to unlock picks.",
            "Rate %{count} more to unlock picks.",
            @remaining
          )}
        </p>
      </div>
      <div class="mt-3 h-4 w-full rounded-base border-2 border-border bg-bw overflow-hidden">
        <div class="h-full bg-main" style={"width: #{@pct}%"}></div>
      </div>
    </div>
    """
  end

  attr :game, :map, required: true
  attr :score, :any, required: true

  defp onboarding_card(assigns) do
    ~H"""
    <div class="rounded-base border-2 border-border bg-bw shadow-brutalist overflow-hidden">
      <div class="aspect-square bg-bg flex items-center justify-center border-b-2 border-border">
        <img
          :if={@game.image_url}
          src={@game.image_url}
          alt={@game.name}
          class="max-w-full max-h-full object-contain"
          loading="lazy"
        />
      </div>
      <div class="p-3">
        <h2 class="font-heading text-sm truncate">{@game.name}</h2>
        <p :if={@game.year_published} class="text-xs font-base">{@game.year_published}</p>
      </div>
      <div class="px-2 py-2 border-t-2 border-border">
        <div class="flex items-center justify-between mb-1 px-1">
          <span class="text-[10px] font-heading uppercase tracking-wide">
            {if @score, do: gettext("Your rating"), else: gettext("Rate this")}
          </span>
          <div class="flex items-center gap-1">
            <span :if={@score} class="text-xs font-heading">{trunc(@score)}/10</span>
            <button
              :if={@score}
              phx-click="clear_rating"
              phx-value-game-id={@game.id}
              class="rounded-sm border border-border bg-bw px-1 text-[10px] font-heading leading-none hover:bg-red-300 transition-colors"
              aria-label={gettext("Clear rating")}
              title={gettext("Clear rating")}
            >
              &times;
            </button>
          </div>
        </div>
        <div class="grid grid-cols-10 gap-0.5">
          <button
            :for={n <- 1..10}
            phx-click="rate"
            phx-value-game-id={@game.id}
            phx-value-score={n}
            class={[
              "h-6 rounded-sm border border-border text-[10px] font-heading transition-colors",
              rate_active?(n, @score) && "bg-main",
              !rate_active?(n, @score) && "bg-bw hover:bg-main/50"
            ]}
            aria-label={gettext("Rate %{score} out of 10", score: n)}
          >
            {n}
          </button>
        </div>
        <button
          phx-click="dismiss"
          phx-value-game-id={@game.id}
          class="mt-2 w-full rounded-sm border border-border bg-bw px-2 py-1 text-[10px] font-heading hover:bg-bg transition-colors"
        >
          {gettext("Haven't played")}
        </button>
      </div>
    </div>
    """
  end

  defp rate_active?(_n, nil), do: false
  defp rate_active?(n, score) when is_number(score), do: n <= trunc(score)
end
