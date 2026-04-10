defmodule ReccoWeb.GameLive.Show do
  use ReccoWeb, :live_view

  alias Recco.BoardGames

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"id" => id}, _session, socket) do
    case BoardGames.get_board_game(id) do
      {:ok, game} ->
        {:ok,
         assign(socket,
           page_title: game.name,
           game: game
         )}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Game not found")
         |> redirect(to: ~p"/games")}
    end
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <a href={~p"/games"} class="text-sm text-brand-600 hover:underline mb-4 inline-block">
        &larr; Back to browse
      </a>

      <div class="flex flex-col md:flex-row gap-8">
        <div class="w-full md:w-1/3 lg:w-1/4 flex-shrink-0">
          <div class="aspect-square rounded-lg bg-zinc-100 overflow-hidden">
            <img
              :if={@game.image_url}
              src={@game.image_url}
              alt={@game.name}
              class="w-full h-full object-cover"
            />
          </div>
        </div>

        <div class="flex-1 min-w-0">
          <h1 class="text-3xl font-bold text-zinc-900">{@game.name}</h1>
          <p :if={@game.year_published} class="text-zinc-500 mt-1">
            {@game.year_published}
          </p>

          <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-6">
            <.stat label="Rating" value={format_rating(@game.average_rating)} />
            <.stat label="Weight" value={format_rating(@game.average_weight)} />
            <.stat label="Players" value={format_players(@game.min_players, @game.max_players)} />
            <.stat
              label="Time"
              value={format_playtime(@game.min_playtime, @game.max_playtime)}
            />
          </div>

          <div :if={@game.description} class="mt-6">
            <h2 class="text-sm font-semibold text-zinc-700 mb-2">Description</h2>
            <p class="text-sm text-zinc-600 leading-relaxed">{@game.description}</p>
          </div>

          <div :if={@game.categories != []} class="mt-6">
            <h2 class="text-sm font-semibold text-zinc-700 mb-2">Categories</h2>
            <div class="flex flex-wrap gap-2">
              <span
                :for={cat <- @game.categories}
                class="inline-block rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-700"
              >
                {cat["value"]}
              </span>
            </div>
          </div>

          <div :if={@game.mechanics != []} class="mt-4">
            <h2 class="text-sm font-semibold text-zinc-700 mb-2">Mechanics</h2>
            <div class="flex flex-wrap gap-2">
              <span
                :for={mech <- @game.mechanics}
                class="inline-block rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-700"
              >
                {mech["value"]}
              </span>
            </div>
          </div>

          <div :if={@game.designers != []} class="mt-4">
            <h2 class="text-sm font-semibold text-zinc-700 mb-2">Designers</h2>
            <p class="text-sm text-zinc-600">
              {Enum.map_join(@game.designers, ", ", & &1["value"])}
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp stat(assigns) do
    ~H"""
    <div class="rounded-lg bg-zinc-50 p-3">
      <p class="text-xs text-zinc-500">{@label}</p>
      <p class="text-lg font-semibold text-zinc-900">{@value}</p>
    </div>
    """
  end

  defp format_rating(nil), do: "N/A"
  defp format_rating(val), do: :erlang.float_to_binary(val / 1, decimals: 1)

  defp format_players(nil, nil), do: "N/A"
  defp format_players(min, max) when min == max, do: "#{min}"
  defp format_players(min, max), do: "#{min}-#{max}"

  defp format_playtime(nil, nil), do: "N/A"
  defp format_playtime(min, max) when min == max, do: "#{min}m"
  defp format_playtime(min, max), do: "#{min}-#{max}m"
end
