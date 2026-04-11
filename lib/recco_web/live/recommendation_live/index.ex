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
      <h1 class="text-2xl font-bold mb-6">Recommendations</h1>
      <p class="text-sm font-medium mb-6">
        Personalised picks based on your ratings.
      </p>

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
              The recommendation engine is currently unavailable. Please try again later.
            <% _ -> %>
              Something went wrong loading recommendations.
          <% end %>
        </p>
      </div>

      <div
        :if={@recommendations == []}
        class="text-center py-16 rounded-base border-2 border-border bg-bw shadow-brutalist"
      >
        <p class="font-medium">Rate some games first to get personalised recommendations.</p>
        <a
          href={~p"/games"}
          class="mt-4 inline-block rounded-base border-2 border-border bg-main px-4 py-2 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
        >
          Browse games
        </a>
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
        />
      </div>
    </div>
    """
  end

  attr :rec, :map, required: true
  attr :rank, :integer, required: true
  attr :total, :integer, required: true

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
      <% else %>
        <div class="p-3">
          <h2 class="font-bold text-sm">{@rec.name}</h2>
          <p class="text-xs font-medium mt-1">{@match_label}</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp match_label(rank, total) do
    percentile = rank / max(total - 1, 1)

    cond do
      rank == 0 -> {"Top pick", "bg-main"}
      percentile <= 0.15 -> {"Excellent match", "bg-main"}
      percentile <= 0.4 -> {"Great match", "bg-main/60"}
      percentile <= 0.7 -> {"Good match", "bg-bg"}
      true -> {"Worth a look", "bg-bg"}
    end
  end
end
