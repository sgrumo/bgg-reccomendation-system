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
    <div class="max-w-5xl mx-auto pb-12">
      <div class="text-center mb-8">
        <div class="label mb-2">{gettext("Step 1 of 1")}</div>
        <h1 class="text-[clamp(34px,4vw,58px)] mb-3">
          {gettext("Welcome! Tell us what you like")}
        </h1>
        <p class="text-ink-soft text-base max-w-xl mx-auto">
          {gettext(
            "Rate any games you've played below. Even 3-5 ratings are enough to start getting personalised picks — the more you rate, the sharper they get."
          )}
        </p>
      </div>

      <.progress_banner rated_count={@rated_count} ratings_threshold={@ratings_threshold} />

      <form phx-change="search" phx-submit="search" class="mb-6">
        <input
          type="text"
          name="search"
          value={@search}
          placeholder={gettext("Search for a game you've played…")}
          class="field"
          phx-debounce="300"
          aria-label={gettext("Search games")}
        />
      </form>

      <p :if={@search != ""} class="label mb-3">
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
        <button type="button" phx-click="skip" class="btn btn-ghost">
          {gettext("Skip for now")}
        </button>
        <button type="button" phx-click="finish" class="btn btn-primary btn-lg">
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
    <div class="panel bg-card2 px-5 py-4 mb-6">
      <div class="flex items-center justify-between gap-3 flex-wrap">
        <p class="font-bold">
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
        <p :if={@remaining > 0} class="text-ink-soft text-sm">
          {ngettext(
            "Rate %{count} more to unlock picks.",
            "Rate %{count} more to unlock picks.",
            @remaining
          )}
        </p>
      </div>
      <div class="mt-3 h-4 w-full border-2 border-line rounded-panel-sm bg-card overflow-hidden">
        <div class="h-full bg-accent" style={"width: #{@pct}%"}></div>
      </div>
    </div>
    """
  end

  attr :game, :map, required: true
  attr :score, :any, required: true

  defp onboarding_card(assigns) do
    ~H"""
    <article class="panel overflow-hidden flex flex-col">
      <div class="aspect-square bg-card2 grid place-items-center border-b-bw border-line overflow-hidden">
        <img
          :if={@game.image_url}
          src={@game.image_url}
          alt={@game.name}
          class="max-w-full max-h-full object-contain"
          loading="lazy"
        />
      </div>
      <div class="p-3.5 flex-1 flex flex-col gap-2.5">
        <div>
          <h3 class="text-[19px] leading-tight truncate">{@game.name}</h3>
          <p :if={@game.year_published} class="font-mono text-ink-soft text-[13px] mt-1">
            {@game.year_published}
          </p>
        </div>
        <div class="mt-auto">
          <div class="flex items-center justify-between gap-2 mb-1.5 min-h-[28px]">
            <span class="label !text-[10.5px]">
              {if @score, do: gettext("Your rating"), else: gettext("Rate this")}
            </span>
            <button
              :if={@score}
              type="button"
              phx-click="clear_rating"
              phx-value-game-id={@game.id}
              class="btn btn-ghost btn-sm !py-1 !px-2.5 !gap-1.5 !text-[12px] !font-bold hover:!bg-danger hover:!text-accent-ink"
              aria-label={gettext("Clear rating")}
            >
              <span aria-hidden="true" class="text-base leading-none">×</span>
              {gettext("Clear")}
            </button>
          </div>
          <form phx-change="rate" class="flex items-center gap-3">
            <input type="hidden" name="game-id" value={@game.id} />
            <input
              type="range"
              name="score"
              min="1"
              max="10"
              step="1"
              value={slider_value(@score)}
              phx-debounce="250"
              data-unrated={if @score, do: "false", else: "true"}
              class="rate-slider flex-1"
              aria-label={gettext("Rate %{game} out of 10", game: @game.name)}
              aria-valuenow={trunc(@score || 0)}
            />
            <span class={[
              "font-mono font-bold text-sm tabular-nums min-w-[44px] text-right",
              !@score && "text-ink-soft"
            ]}>
              {if @score, do: "#{trunc(@score)}/10", else: "—/10"}
            </span>
          </form>
          <button
            type="button"
            phx-click="dismiss"
            phx-value-game-id={@game.id}
            class="btn btn-ghost btn-sm w-full justify-center mt-2 !text-[12px]"
          >
            {gettext("Haven't played")}
          </button>
        </div>
      </div>
    </article>
    """
  end

  defp slider_value(nil), do: 5
  defp slider_value(score) when is_number(score), do: trunc(score)
end
