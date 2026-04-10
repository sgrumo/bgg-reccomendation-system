defmodule ReccoWeb.Admin.DashboardLive do
  use ReccoWeb, :live_view

  alias Recco.Accounts
  alias Recco.BoardGames
  alias Recco.Ratings

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       user_count: Accounts.count_users(),
       game_count: BoardGames.board_game_count(),
       total_ratings: Ratings.total_ratings_count()
     )}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold text-zinc-900 mb-8">Dashboard</h1>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <.stat_card title="Users" value={@user_count} href={~p"/admin/users"} />
        <.stat_card title="Board Games" value={@game_count} />
        <.stat_card title="Total Ratings" value={@total_ratings} />
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :href, :string, default: nil

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 bg-white p-6">
      <p class="text-sm font-medium text-zinc-500">{@title}</p>
      <p class="mt-2 text-3xl font-bold text-zinc-900">{@value}</p>
      <a :if={@href} href={@href} class="mt-3 inline-block text-sm text-brand-600 hover:underline">
        View all &rarr;
      </a>
    </div>
    """
  end
end
