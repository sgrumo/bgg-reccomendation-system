defmodule ReccoWeb.RecommendationLive.Index do
  use ReccoWeb, :live_view

  alias Recco.Recommender

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    socket =
      socket
      |> assign(page_title: "Recommendations", recommendations: nil, loading: true, error: nil)
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
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold text-zinc-900 mb-6">Recommendations</h1>
      <p class="text-sm text-zinc-500 mb-6">
        Personalised picks based on your ratings.
      </p>

      <div :if={@loading} class="space-y-4">
        <.loading_skeleton :for={_ <- 1..6} />
      </div>

      <div :if={@error} class="text-center py-16">
        <p class="text-zinc-500">
          <%= case @error do %>
            <% :service_unavailable -> %>
              The recommendation engine is currently unavailable. Please try again later.
            <% _ -> %>
              Something went wrong loading recommendations.
          <% end %>
        </p>
      </div>

      <div :if={@recommendations == []} class="text-center py-16 text-zinc-500">
        <p>Rate some games first to get personalised recommendations.</p>
        <a href={~p"/games"} class="mt-4 inline-block text-brand-600 hover:underline">
          Browse games
        </a>
      </div>

      <div
        :if={@recommendations && @recommendations != []}
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
      >
        <.recommendation_card :for={rec <- @recommendations} rec={rec} />
      </div>
    </div>
    """
  end

  attr :rec, :map, required: true

  defp recommendation_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 overflow-hidden">
      <%= if @rec.game do %>
        <a href={~p"/games/#{@rec.game.id}"} class="block hover:shadow-sm transition">
          <div class="aspect-[4/3] bg-zinc-100 flex items-center justify-center">
            <img
              :if={@rec.game.image_url}
              src={@rec.game.image_url}
              alt={@rec.name}
              class="max-w-full max-h-full object-contain"
              loading="lazy"
            />
          </div>
          <div class="p-3">
            <h2 class="font-semibold text-zinc-900 text-sm truncate">{@rec.name}</h2>
            <div class="flex items-center justify-between mt-1 text-xs text-zinc-500">
              <span>Match: {format_score(@rec.score)}</span>
              <span :if={@rec.game.average_rating} class="font-medium text-zinc-700">
                {Float.round(@rec.game.average_rating, 1)}
              </span>
            </div>
          </div>
        </a>
      <% else %>
        <div class="p-3">
          <h2 class="font-semibold text-zinc-900 text-sm">{@rec.name}</h2>
          <p class="text-xs text-zinc-500 mt-1">Match: {format_score(@rec.score)}</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp loading_skeleton(assigns) do
    ~H"""
    <div class="animate-pulse flex gap-4 rounded-lg border border-zinc-200 p-4">
      <div class="w-16 h-16 bg-zinc-200 rounded"></div>
      <div class="flex-1 space-y-2 py-1">
        <div class="h-4 bg-zinc-200 rounded w-3/4"></div>
        <div class="h-3 bg-zinc-200 rounded w-1/2"></div>
      </div>
    </div>
    """
  end

  defp format_score(score) when is_float(score) do
    "#{round(score * 100)}%"
  end

  defp format_score(_), do: "N/A"
end
