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
    <div>
      <h1 class="text-2xl font-bold mb-2">{gettext("Recommendations")}</h1>
      <p class="text-sm font-medium mb-6">
        {gettext("Personalised picks based on your ratings.")}
      </p>

      <.progress_banner rating_count={@rating_count} ratings_threshold={@ratings_threshold} />

      <div :if={@loading} class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <div :for={_ <- 1..6} class="rounded-base border-2 border-border bg-bw p-4">
          <div class="h-32 bg-bg rounded-base mb-3 animate-pulse"></div>
          <div class="h-4 bg-bg rounded-base w-3/4 animate-pulse"></div>
          <div class="h-3 bg-bg rounded-base w-1/2 mt-2 animate-pulse"></div>
        </div>
      </div>

      <div
        :if={@error}
        class="text-center py-16 rounded-base border-2 border-border bg-bw shadow-brutalist"
      >
        <p class="font-medium">
          <%= case @error do %>
            <% :service_unavailable -> %>
              {gettext("The recommendation engine is currently unavailable. Please try again later.")}
            <% _ -> %>
              {gettext("Something went wrong loading recommendations.")}
          <% end %>
        </p>
      </div>

      <div
        :if={@recommendations == []}
        class="text-center py-16 rounded-base border-2 border-border bg-bw shadow-brutalist"
      >
        <p class="text-lg font-bold">
          {gettext("No recommendations yet")}
        </p>
        <p class="text-sm font-medium mt-2 max-w-md mx-auto">
          {gettext(
            "Rate a handful of games you've played — even 5 is enough to get started. The more you rate, the sharper your picks."
          )}
        </p>
        <div class="mt-5 flex items-center justify-center gap-3 flex-wrap">
          <a
            href={~p"/games"}
            class="inline-block rounded-base border-2 border-border bg-main px-4 py-2 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
          >
            {gettext("Browse games to rate")}
          </a>
          <a
            href={~p"/profile"}
            class="inline-block rounded-base border-2 border-border bg-bw px-4 py-2 text-sm font-bold hover:bg-main transition-colors"
          >
            {gettext("Or import from BGG")}
          </a>
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
    {label, color} = match_label(assigns.rank, assigns.total)
    assigns = assign(assigns, match_label: label, match_color: color)

    ~H"""
    <div class="rounded-base border-2 border-border bg-bw shadow-brutalist overflow-hidden">
      <%= if @rec.game do %>
        <a
          href={~p"/games/#{@rec.game.id}"}
          class="block hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
        >
          <div class="aspect-[4/3] bg-bg flex items-center justify-center border-b-2 border-border">
            <img
              :if={@rec.game.image_url}
              src={@rec.game.image_url}
              alt={@rec.name}
              class="max-w-full max-h-full object-contain"
              loading="lazy"
            />
          </div>
          <div class="p-3">
            <h2 class="font-bold text-sm truncate">{@rec.name}</h2>
            <div class="flex items-center justify-between mt-1 text-xs font-medium">
              <span class={[
                "inline-flex items-center rounded-base border-2 border-border px-1.5 py-0.5 text-xs font-bold",
                @match_color
              ]}>
                {@match_label}
              </span>
              <span
                :if={@rec.game.average_rating}
                class="inline-flex items-center rounded-base border-2 border-border bg-main px-1.5 py-0.5 text-xs font-bold"
              >
                {Float.round(@rec.game.average_rating, 1)}
              </span>
            </div>
          </div>
        </a>
        <div class="flex items-center gap-1 px-3 pb-3">
          <span class="text-xs font-medium mr-1">{gettext("Useful?")}</span>
          <button
            phx-click="feedback"
            phx-value-game-id={@rec.game.id}
            phx-value-positive="true"
            class={[
              "rounded-base border-2 border-border px-2 py-0.5 text-xs font-bold transition-all",
              @feedback == true && "bg-main",
              @feedback != true && "bg-bw hover:bg-bg"
            ]}
            aria-label={gettext("Good recommendation")}
          >
            &#x1F44D;
          </button>
          <button
            phx-click="feedback"
            phx-value-game-id={@rec.game.id}
            phx-value-positive="false"
            class={[
              "rounded-base border-2 border-border px-2 py-0.5 text-xs font-bold transition-all",
              @feedback == false && "bg-red-300",
              @feedback != false && "bg-bw hover:bg-bg"
            ]}
            aria-label={gettext("Bad recommendation")}
          >
            &#x1F44E;
          </button>
        </div>
      <% else %>
        <div class="p-3">
          <h2 class="font-bold text-sm">{@rec.name}</h2>
          <p class="text-xs font-medium mt-1">{@match_label}</p>
        </div>
      <% end %>
    </div>
    """
  end

  attr :rating_count, :integer, required: true
  attr :ratings_threshold, :integer, required: true

  defp progress_banner(%{rating_count: count, ratings_threshold: threshold} = assigns)
       when count >= threshold do
    ~H"""
    <div class="mb-6 rounded-base border-2 border-border bg-main/30 p-4 shadow-brutalist">
      <div class="flex items-start justify-between gap-3 flex-wrap">
        <div>
          <p class="text-sm font-bold">
            {gettext("%{count} ratings — picks are live.", count: @rating_count)}
          </p>
          <p class="text-xs font-medium mt-0.5">
            {gettext(
              "Want sharper recommendations? Rate more games, or import your ratings from BoardGameGeek."
            )}
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <a
            href={~p"/games"}
            class="rounded-base border-2 border-border bg-bw px-3 py-1.5 text-xs font-bold hover:bg-main transition-colors"
          >
            {gettext("Rate more")} &rarr;
          </a>
          <a
            href={~p"/profile"}
            class="rounded-base border-2 border-border bg-bw px-3 py-1.5 text-xs font-bold hover:bg-main transition-colors"
          >
            {gettext("Import from BGG")} &rarr;
          </a>
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
    <div class="mb-6 rounded-base border-2 border-border bg-main/30 p-4 shadow-brutalist">
      <div class="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <p class="text-sm font-bold">
            {gettext("%{count} of %{total} ratings",
              count: @rating_count,
              total: @ratings_threshold
            )}
          </p>
          <p class="text-xs font-medium mt-0.5">
            {ngettext(
              "Rate %{count} more game to unlock sharper recommendations.",
              "Rate %{count} more games to unlock sharper recommendations.",
              @remaining
            )}
          </p>
        </div>
        <a
          href={~p"/games"}
          class="rounded-base border-2 border-border bg-bw px-3 py-1.5 text-xs font-bold hover:bg-main transition-colors"
        >
          {gettext("Rate more games")} &rarr;
        </a>
      </div>
      <div class="mt-3 h-4 w-full rounded-base border-2 border-border bg-bw overflow-hidden">
        <div class="h-full bg-main" style={"width: #{@pct}%"}></div>
      </div>
    </div>
    """
  end

  defp match_label(rank, total) do
    percentile = rank / max(total - 1, 1)

    cond do
      rank == 0 -> {gettext("Top pick"), "bg-main"}
      percentile <= 0.15 -> {gettext("Excellent match"), "bg-main"}
      percentile <= 0.4 -> {gettext("Great match"), "bg-main/60"}
      percentile <= 0.7 -> {gettext("Good match"), "bg-bg"}
      true -> {gettext("Worth a look"), "bg-bg"}
    end
  end
end
