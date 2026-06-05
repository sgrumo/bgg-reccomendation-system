defmodule ReccoWeb.GameLive.Show do
  use ReccoWeb, :live_view

  alias Recco.BoardGames
  alias Recco.Feedback
  alias Recco.Ratings
  alias Recco.Recommender
  alias Recco.Wishlists

  @ratings_threshold 5

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"id" => id}, _session, socket) do
    case BoardGames.get_board_game(id) do
      {:ok, game} ->
        user_rating = load_user_rating(socket.assigns[:current_user], game.id)
        wishlisted = load_wishlisted(socket.assigns[:current_user], game.id)
        feedback_map = load_feedback_map(socket.assigns[:current_user])
        rating_count = load_rating_count(socket.assigns[:current_user])

        socket =
          socket
          |> assign(
            page_title: game.name,
            game: game,
            user_rating: user_rating,
            rating_form_score: user_rating && user_rating.score,
            wishlisted: wishlisted,
            feedback_map: feedback_map,
            rating_count: rating_count,
            ratings_threshold: @ratings_threshold,
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
         |> put_flash(:error, gettext("Game not found"))
         |> redirect(to: ~p"/games")}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("rate", _params, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, redirect(socket, to: ~p"/login")}
  end

  def handle_event("rate", %{"score" => score_str}, socket) do
    {score, _} = Float.parse(score_str)
    user = socket.assigns.current_user
    was_rated? = socket.assigns.user_rating != nil

    case Ratings.rate_game(user.id, socket.assigns.game.id, %{score: score}) do
      {:ok, rating} ->
        delta = if was_rated?, do: 0, else: 1

        {:noreply,
         assign(socket,
           user_rating: rating,
           rating_form_score: rating.score,
           rating_count: socket.assigns.rating_count + delta
         )}

      {:error, _, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save rating"))}
    end
  end

  def handle_event("remove_rating", _params, socket) do
    user = socket.assigns.current_user

    if user && socket.assigns.user_rating do
      :ok = Ratings.delete_rating(user.id, socket.assigns.game.id)

      {:noreply,
       assign(socket,
         user_rating: nil,
         rating_form_score: nil,
         rating_count: max(socket.assigns.rating_count - 1, 0)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("add_to_wishlist", _params, socket) do
    user = socket.assigns.current_user

    if user do
      case Wishlists.add_to_wishlist(user.id, socket.assigns.game.id) do
        {:ok, _} ->
          {:noreply, assign(socket, wishlisted: true)}

        {:error, _, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not add to wishlist"))}
      end
    else
      {:noreply, redirect(socket, to: ~p"/login")}
    end
  end

  def handle_event("remove_from_wishlist", _params, socket) do
    user = socket.assigns.current_user

    if user && socket.assigns.wishlisted do
      :ok = Wishlists.remove_from_wishlist(user.id, socket.assigns.game.id)
      {:noreply, assign(socket, wishlisted: false)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("feedback", %{"game-id" => game_id, "positive" => positive_str}, socket) do
    user = socket.assigns.current_user

    if user do
      positive = positive_str == "true"
      current = Map.get(socket.assigns.feedback_map, game_id)

      if current == positive do
        :ok = Feedback.delete_feedback(user.id, game_id)
        {:noreply, assign(socket, feedback_map: Map.delete(socket.assigns.feedback_map, game_id))}
      else
        {:ok, _} =
          Feedback.upsert_feedback(user.id, game_id, %{
            positive: positive,
            source: "similar_games"
          })

        {:noreply,
         assign(socket, feedback_map: Map.put(socket.assigns.feedback_map, game_id, positive))}
      end
    else
      {:noreply, redirect(socket, to: ~p"/login")}
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
    <div class="pb-16">
      <a href={~p"/games"} class="btn btn-ghost btn-sm !pl-0 mb-5">
        ← {gettext("Back to browse")}
      </a>

      <div class="grid grid-cols-1 lg:grid-cols-[360px_1fr] gap-10 items-start">
        <div class="lg:sticky lg:top-[90px]">
          <div
            class="aspect-[0.78/1] border-bw border-line rounded-panel shadow-panel-lg overflow-hidden bg-card2 grid place-items-center"
            style="transform: rotate(-1.2deg);"
          >
            <img
              :if={@game.image_url}
              src={@game.image_url}
              alt={@game.name}
              class="max-w-full max-h-full object-contain"
            />
          </div>

          <.wishlist_button current_user={@current_user} wishlisted={@wishlisted} />
        </div>

        <div class="min-w-0">
          <div class="label mb-2">{header_eyebrow(@game)}</div>
          <h1 class="text-[clamp(44px,5.4vw,76px)] mb-5 break-words">{@game.name}</h1>

          <div class="flex flex-wrap gap-3.5 mb-7">
            <.stat
              :if={@game.average_rating}
              label={gettext("Rating")}
              value={format_rating(@game.average_rating)}
              sub="/10"
            />
            <.stat
              :if={@game.users_rated}
              label={gettext("Votes")}
              value={format_votes(@game.users_rated)}
            />
            <.stat
              :if={@game.average_weight}
              label={gettext("Weight")}
              value={format_rating(@game.average_weight)}
              sub="/5"
            />
            <.stat
              :if={@game.min_players && @game.max_players}
              label={gettext("Players")}
              value={format_players(@game.min_players, @game.max_players)}
            />
            <.stat
              :if={@game.min_playtime && @game.max_playtime}
              label={gettext("Time")}
              value={format_playtime(@game.min_playtime, @game.max_playtime)}
              sub="min"
            />
          </div>

          <.rating_panel
            current_user={@current_user}
            user_rating={@user_rating}
            rating_form_score={@rating_form_score}
            rating_count={@rating_count}
            ratings_threshold={@ratings_threshold}
            game={@game}
          />

          <div :if={@game.description} class="panel px-6 py-5 mb-7">
            <h3 class="text-[22px] mb-3">{gettext("Description")}</h3>
            <p class="text-[16.5px] leading-[1.62] text-ink">{@game.description}</p>
          </div>

          <div class="grid gap-5">
            <div :if={@game.categories != []}>
              <div class="label mb-2.5">{gettext("Categories")}</div>
              <div class="flex flex-wrap gap-2">
                <span :for={cat <- @game.categories} class="chip chip-accent">{cat["value"]}</span>
              </div>
            </div>

            <div :if={@game.mechanics != []}>
              <div class="label mb-2.5">{gettext("Mechanics")}</div>
              <div class="flex flex-wrap gap-2">
                <span :for={mech <- @game.mechanics} class="chip">{mech["value"]}</span>
              </div>
            </div>

            <div :if={@game.designers != []}>
              <div class="label mb-2.5">{gettext("Designers")}</div>
              <div class="flex flex-wrap gap-2">
                <span :for={d <- @game.designers} class="chip">{d["value"]}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <section class="mt-14">
        <h2 class="text-[clamp(28px,3.2vw,44px)] mb-5">{gettext("Similar Games")}</h2>

        <div :if={@similar_loading} class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          <div :for={_ <- 1..6} class="panel p-4">
            <div class="aspect-[1.2/1] bg-card2 mb-3 animate-pulse"></div>
            <div class="h-4 bg-card2 w-3/4 animate-pulse"></div>
          </div>
        </div>

        <div
          :if={!@similar_loading && (@similar_games == nil || @similar_games == [])}
          class="text-ink-soft"
        >
          {gettext("No similar games found.")}
        </div>

        <div
          :if={!@similar_loading && @similar_games && @similar_games != []}
          class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5"
        >
          <.similar_card
            :for={rec <- @similar_games}
            :if={rec.game}
            rec={rec}
            current_user={@current_user}
            feedback_map={@feedback_map}
          />
        </div>
      </section>
    </div>
    """
  end

  ## ── stat tile ─────────────────────────────────────────────────────────

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :sub, :string, default: nil

  defp stat(assigns) do
    ~H"""
    <div class="panel panel-sm px-4 py-3.5 flex-1 min-w-[110px]">
      <div class="label !text-[11px]">{@label}</div>
      <div class="flex items-baseline gap-1.5 mt-1">
        <span class="font-mono font-bold text-[26px] leading-none text-ink">{@value}</span>
        <span :if={@sub} class="text-ink-soft text-[13px]">{@sub}</span>
      </div>
    </div>
    """
  end

  ## ── rating panel ──────────────────────────────────────────────────────

  attr :current_user, :any, required: true
  attr :user_rating, :any, required: true
  attr :rating_form_score, :any, required: true
  attr :rating_count, :integer, required: true
  attr :ratings_threshold, :integer, required: true
  attr :game, :map, required: true

  defp rating_panel(assigns) do
    ~H"""
    <div class="panel px-6 py-5 mb-5">
      <div class="flex items-start justify-between gap-4 flex-wrap mb-4">
        <div>
          <h3 class="text-2xl mb-1">
            {if @user_rating, do: gettext("Your rating"), else: gettext("Rate this game")}
          </h3>
          <p class="text-ink-soft text-sm">
            {rating_nudge(@current_user, @user_rating, @rating_count, @ratings_threshold)}
          </p>
        </div>
        <a
          :if={@current_user && @rating_count >= @ratings_threshold}
          href={~p"/recommendations"}
          class="btn btn-sm whitespace-nowrap"
        >
          {gettext("See your picks")} →
        </a>
      </div>

      <%= if @current_user do %>
        <form phx-change="rate" class="flex items-center gap-4">
          <input
            type="range"
            name="score"
            min="1"
            max="10"
            step="1"
            value={slider_value(@rating_form_score)}
            phx-debounce="250"
            data-unrated={if @user_rating, do: "false", else: "true"}
            class="rate-slider flex-1"
            aria-label={gettext("Rate %{game} out of 10", game: @game.name)}
            aria-valuenow={trunc(@rating_form_score || 0)}
          />
          <span class={[
            "font-mono font-bold text-base tabular-nums min-w-[52px] text-right",
            !@user_rating && "text-ink-soft"
          ]}>
            {if @user_rating,
              do: "#{:erlang.float_to_binary(@user_rating.score, decimals: 1)}/10",
              else: "—/10"}
          </span>
        </form>

        <div class="flex items-center justify-between mt-4 gap-3 flex-wrap">
          <span class={[
            "font-bold text-sm",
            (@user_rating && "text-good") || "text-ink-soft"
          ]}>
            <%= if @user_rating do %>
              ✓ {gettext("Saved — you rated this %{score}/10",
                score: :erlang.float_to_binary(@user_rating.score, decimals: 1)
              )}
            <% else %>
              {gettext("Drag to set a rating.")}
            <% end %>
          </span>
          <button
            :if={@user_rating}
            type="button"
            phx-click="remove_rating"
            class="btn btn-sm hover:!bg-danger hover:!text-accent-ink"
          >
            {gettext("Clear")}
          </button>
        </div>
      <% else %>
        <p class="text-base text-ink">
          <a href={~p"/login"} class="font-bold underline decoration-2 underline-offset-2">
            {gettext("Sign in")}
          </a>
          {gettext("to rate this game and unlock personalised picks.")}
        </p>
      <% end %>
    </div>
    """
  end

  ## ── wishlist button (below cover) ─────────────────────────────────────

  attr :current_user, :any, required: true
  attr :wishlisted, :boolean, required: true

  defp wishlist_button(assigns) do
    ~H"""
    <%= if @current_user do %>
      <%= if @wishlisted do %>
        <button
          type="button"
          phx-click="remove_from_wishlist"
          class="btn btn-primary w-full justify-center mt-5"
        >
          ✓ {gettext("On your wishlist")}
        </button>
      <% else %>
        <button
          type="button"
          phx-click="add_to_wishlist"
          class="btn w-full justify-center mt-5"
        >
          + {gettext("Add to wishlist")}
        </button>
      <% end %>
    <% else %>
      <a href={~p"/login"} class="btn w-full justify-center mt-5">
        {gettext("Sign in to wishlist")}
      </a>
    <% end %>
    """
  end

  ## ── similar games card ────────────────────────────────────────────────

  attr :rec, :map, required: true
  attr :current_user, :any, required: true
  attr :feedback_map, :map, required: true

  defp similar_card(assigns) do
    ~H"""
    <article class="panel lift overflow-hidden flex flex-col">
      <a href={~p"/games/#{@rec.game.id}"} class="block">
        <div class="aspect-[1.2/1] bg-card2 grid place-items-center border-b-bw border-line overflow-hidden">
          <img
            :if={@rec.game.image_url}
            src={@rec.game.image_url}
            alt={@rec.name}
            class="max-w-full max-h-full object-contain"
            loading="lazy"
          />
        </div>
      </a>
      <div class="p-3.5 flex-1 flex flex-col gap-2.5">
        <a href={~p"/games/#{@rec.game.id}"} class="block">
          <div class="flex items-baseline justify-between gap-2">
            <h3 class="text-[19px] leading-tight">{@rec.name}</h3>
            <span
              :if={@rec.game.average_rating}
              class="font-mono text-ink-soft text-[13px] whitespace-nowrap pt-0.5"
            >
              ★ {format_rating(@rec.game.average_rating)}
            </span>
          </div>
        </a>

        <div :if={@current_user} class="flex items-center gap-2 mt-auto">
          <span class="label !text-[10.5px]">{gettext("Useful?")}</span>
          <button
            type="button"
            phx-click="feedback"
            phx-value-game-id={@rec.game.id}
            phx-value-positive="true"
            class={[
              "btn btn-sm !py-1 !px-2.5",
              Map.get(@feedback_map, @rec.game.id) == true && "btn-primary"
            ]}
            aria-label={gettext("Good recommendation")}
            aria-pressed={Map.get(@feedback_map, @rec.game.id) == true}
          >
            👍
          </button>
          <button
            type="button"
            phx-click="feedback"
            phx-value-game-id={@rec.game.id}
            phx-value-positive="false"
            class={[
              "btn btn-sm !py-1 !px-2.5",
              Map.get(@feedback_map, @rec.game.id) == false && "!bg-danger !text-accent-ink"
            ]}
            aria-label={gettext("Bad recommendation")}
            aria-pressed={Map.get(@feedback_map, @rec.game.id) == false}
          >
            👎
          </button>
        </div>
      </div>
    </article>
    """
  end

  ## ── nudges & formatters ──────────────────────────────────────────────

  defp rating_nudge(nil, _rating, _count, _threshold) do
    gettext("Rate games to unlock personalised recommendations.")
  end

  defp rating_nudge(_user, _rating, count, threshold) when count >= threshold do
    gettext("Picks are live — rate more or import from BGG for sharper recommendations.")
  end

  defp rating_nudge(_user, _rating, count, threshold) do
    remaining = threshold - count

    ngettext(
      "Rate %{count} more game to unlock personalised picks.",
      "Rate %{count} more games to unlock personalised picks.",
      remaining
    )
  end

  defp slider_value(nil), do: 5
  defp slider_value(score) when is_number(score), do: trunc(score)

  defp header_eyebrow(%{publishers: [%{"value" => v} | _], year_published: y}) when is_integer(y),
    do: "#{v} · #{y}"

  defp header_eyebrow(%{publishers: [%{"value" => v} | _]}), do: v
  defp header_eyebrow(%{year_published: y}) when is_integer(y), do: Integer.to_string(y)
  defp header_eyebrow(_), do: ""

  defp format_votes(n) when n >= 1000, do: "#{Float.round(n / 1000, 1)}k"
  defp format_votes(n) when is_integer(n), do: to_string(n)

  defp format_rating(val) when is_number(val), do: :erlang.float_to_binary(val / 1, decimals: 1)

  defp format_players(min, max) when min == max, do: "#{min}"
  defp format_players(min, max), do: "#{min}–#{max}"

  defp format_playtime(min, max) when min == max, do: to_string(min)
  defp format_playtime(min, max), do: "#{min}–#{max}"

  defp load_user_rating(nil, _game_id), do: nil
  defp load_user_rating(user, game_id), do: Ratings.get_user_rating(user.id, game_id)

  defp load_wishlisted(nil, _game_id), do: false
  defp load_wishlisted(user, game_id), do: Wishlists.wishlisted?(user.id, game_id)

  defp load_feedback_map(nil), do: %{}
  defp load_feedback_map(user), do: Feedback.user_feedback_map(user.id)

  defp load_rating_count(nil), do: 0
  defp load_rating_count(user), do: Ratings.count_user_ratings(user.id)
end
