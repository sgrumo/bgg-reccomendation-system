defmodule ReccoWeb.RecommendationLive.Index do
  use ReccoWeb, :live_view

  alias Recco.Feedback
  alias Recco.Ratings
  alias Recco.Recommender

  @ratings_threshold 5

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    feedback_map = Feedback.user_feedback_map(user_id)
    rating_count = Ratings.count_user_ratings(user_id)

    socket =
      socket
      |> assign(
        page_title: gettext("Recommendations"),
        recommendations: nil,
        loading: true,
        error: nil,
        feedback_map: feedback_map,
        rating_count: rating_count,
        ratings_threshold: @ratings_threshold
      )
      |> start_async(:fetch_recommendations, fn ->
        Recommender.user_recommendations(user_id)
      end)

    {:ok, socket}
  end

  @impl true
  @spec handle_async(atom(), {:ok, term()} | {:exit, term()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_async(:fetch_recommendations, {:ok, {:ok, recs}}, socket) do
    enriched = Recommender.enrich_with_games(recs)
    {:noreply, assign(socket, recommendations: enriched, loading: false)}
  end

  def handle_async(:fetch_recommendations, {:ok, {:error, reason}}, socket) do
    {:noreply, assign(socket, error: reason, loading: false)}
  end

  def handle_async(:fetch_recommendations, {:exit, _reason}, socket) do
    {:noreply, assign(socket, error: :service_unavailable, loading: false)}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("feedback", %{"game-id" => game_id, "positive" => positive_str}, socket) do
    user_id = socket.assigns.current_user.id
    positive = positive_str == "true"
    current = Map.get(socket.assigns.feedback_map, game_id)

    if current == positive do
      :ok = Feedback.delete_feedback(user_id, game_id)
      {:noreply, assign(socket, feedback_map: Map.delete(socket.assigns.feedback_map, game_id))}
    else
      {:ok, _} =
        Feedback.upsert_feedback(user_id, game_id, %{
          positive: positive,
          source: "user_recommendations"
        })

      {:noreply,
       assign(socket, feedback_map: Map.put(socket.assigns.feedback_map, game_id, positive))}
    end
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="pb-12">
      <div class="label mb-2">{gettext("Personalised picks")}</div>
      <h1 class="text-[clamp(34px,4vw,58px)] mb-2">{gettext("Recommendations")}</h1>
      <p class="text-ink-soft mb-7">
        {gettext("Personalised picks based on your ratings.")}
      </p>

      <.progress_banner rating_count={@rating_count} ratings_threshold={@ratings_threshold} />

      <div :if={@loading} class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <div :for={_ <- 1..6} class="panel p-4">
          <div class="aspect-[4/3] bg-card2 mb-3 animate-pulse"></div>
          <div class="h-4 bg-card2 w-3/4 animate-pulse"></div>
          <div class="h-3 bg-card2 w-1/2 mt-2 animate-pulse"></div>
        </div>
      </div>

      <div :if={@error} class="panel px-6 py-12 text-center">
        <p class="text-ink-soft text-[17px]">
          <%= case @error do %>
            <% :service_unavailable -> %>
              {gettext("The recommendation engine is currently unavailable. Please try again later.")}
            <% _ -> %>
              {gettext("Something went wrong loading recommendations.")}
          <% end %>
        </p>
      </div>

      <div :if={@recommendations == []} class="panel px-6 py-12 text-center">
        <h3 class="text-2xl mb-2">
          {gettext("No recommendations yet")}
        </h3>
        <p class="text-ink-soft max-w-md mx-auto mb-5">
          {gettext(
            "Rate a handful of games you've played — even 5 is enough to get started. The more you rate, the sharper your picks."
          )}
        </p>
        <div class="flex items-center justify-center gap-3 flex-wrap">
          <a href={~p"/games"} class="btn btn-primary">{gettext("Browse games to rate")}</a>
          <a href={~p"/profile"} class="btn">{gettext("Or import from BGG")}</a>
        </div>
      </div>

      <div
        :if={@recommendations && @recommendations != []}
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5"
      >
        <.recommendation_card
          :for={{rec, idx} <- Enum.with_index(@recommendations)}
          rec={rec}
          rank={idx}
          total={length(@recommendations)}
          feedback={Map.get(@feedback_map, rec.game && rec.game.id)}
        />
      </div>
    </div>
    """
  end

  attr :rec, :map, required: true
  attr :rank, :integer, required: true
  attr :total, :integer, required: true
  attr :feedback, :any, required: true

  defp recommendation_card(assigns) do
    {label, accent} = match_label(assigns.rank, assigns.total)
    assigns = assign(assigns, match_label: label, match_accent: accent)

    ~H"""
    <article class="panel lift overflow-hidden flex flex-col">
      <%= if @rec.game do %>
        <a href={~p"/games/#{@rec.game.id}"} class="block">
          <div class="aspect-[4/3] bg-card2 grid place-items-center border-b-bw border-line overflow-hidden">
            <img
              :if={@rec.game.image_url}
              src={@rec.game.image_url}
              alt={@rec.name}
              class="max-w-full max-h-full object-contain"
              loading="lazy"
            />
          </div>
          <div class="p-3.5">
            <h3 class="text-[19px] leading-tight truncate">{@rec.name}</h3>
            <div class="flex items-center justify-between gap-2 mt-2">
              <span class={[
                "chip",
                @match_accent && "chip-accent"
              ]}>
                {@match_label}
              </span>
              <span
                :if={@rec.game.average_rating}
                class="font-mono font-bold text-sm border-2 border-line rounded-panel-sm px-2 py-0.5 bg-card2 text-ink whitespace-nowrap"
              >
                ★ {Float.round(@rec.game.average_rating, 1)}
              </span>
            </div>
          </div>
        </a>
        <div class="flex items-center gap-2 px-3.5 pb-3.5 mt-auto">
          <span class="label !text-[10.5px]">{gettext("Useful?")}</span>
          <button
            type="button"
            phx-click="feedback"
            phx-value-game-id={@rec.game.id}
            phx-value-positive="true"
            class={[
              "btn btn-sm !py-1 !px-2.5",
              @feedback == true && "btn-primary"
            ]}
            aria-label={gettext("Good recommendation")}
            aria-pressed={@feedback == true}
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
              @feedback == false && "!bg-danger !text-accent-ink"
            ]}
            aria-label={gettext("Bad recommendation")}
            aria-pressed={@feedback == false}
          >
            👎
          </button>
        </div>
      <% else %>
        <div class="p-3.5">
          <h3 class="text-[19px] leading-tight">{@rec.name}</h3>
          <p class="text-ink-soft text-sm mt-1">{@match_label}</p>
        </div>
      <% end %>
    </article>
    """
  end

  attr :rating_count, :integer, required: true
  attr :ratings_threshold, :integer, required: true

  defp progress_banner(%{rating_count: count, ratings_threshold: threshold} = assigns)
       when count >= threshold do
    ~H"""
    <div class="panel bg-card2 px-5 py-4 mb-6">
      <div class="flex items-start justify-between gap-3 flex-wrap">
        <div>
          <p class="font-bold">
            {gettext("%{count} ratings — picks are live.", count: @rating_count)}
          </p>
          <p class="text-ink-soft text-sm mt-1">
            {gettext(
              "Want sharper recommendations? Rate more games, or import your ratings from BoardGameGeek."
            )}
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <a href={~p"/games"} class="btn btn-sm">{gettext("Rate more")} →</a>
          <a href={~p"/profile"} class="btn btn-sm">{gettext("Import from BGG")} →</a>
        </div>
      </div>
    </div>
    """
  end

  defp progress_banner(assigns) do
    remaining = assigns.ratings_threshold - assigns.rating_count
    pct = min(round(assigns.rating_count / assigns.ratings_threshold * 100), 100)
    assigns = assign(assigns, remaining: remaining, pct: pct)

    ~H"""
    <div class="panel bg-card2 px-5 py-4 mb-6">
      <div class="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <p class="font-bold">
            {gettext("%{count} of %{total} ratings",
              count: @rating_count,
              total: @ratings_threshold
            )}
          </p>
          <p class="text-ink-soft text-sm mt-1">
            {ngettext(
              "Rate %{count} more game to unlock sharper recommendations.",
              "Rate %{count} more games to unlock sharper recommendations.",
              @remaining
            )}
          </p>
        </div>
        <a href={~p"/games"} class="btn btn-sm">{gettext("Rate more games")} →</a>
      </div>
      <div class="mt-3 h-4 w-full border-2 border-line rounded-panel-sm bg-card overflow-hidden">
        <div class="h-full bg-accent" style={"width: #{@pct}%"}></div>
      </div>
    </div>
    """
  end

  # Returns {label, paint_with_accent?}
  defp match_label(rank, total) do
    percentile = rank / max(total - 1, 1)

    cond do
      rank == 0 -> {gettext("Top pick"), true}
      percentile <= 0.15 -> {gettext("Excellent match"), true}
      percentile <= 0.4 -> {gettext("Great match"), false}
      percentile <= 0.7 -> {gettext("Good match"), false}
      true -> {gettext("Worth a look"), false}
    end
  end
end
