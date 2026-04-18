defmodule ReccoWeb.Admin.UserLive.Show do
  use ReccoWeb, :live_view

  alias Recco.Accounts
  alias Recco.Ratings

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"id" => id}, _session, socket) do
    case Accounts.admin_get_user_by_id(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> redirect(to: ~p"/admin/users")}

      user ->
        ratings = Ratings.list_user_ratings(user.id)
        stats = Ratings.user_stats(user.id)

        {:ok,
         assign(socket,
           page_title: user.username,
           user: user,
           ratings: ratings,
           stats: stats
         )}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("soft_delete_user", _params, socket) do
    case Accounts.soft_delete_user(socket.assigns.user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User anonymized — restorable for 30 days.")
         |> assign(user: user)}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Cannot delete a superadmin.")}

      {:error, :already_deleted} ->
        {:noreply, put_flash(socket, :error, "User is already deleted.")}

      {:error, _, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete user.")}
    end
  end

  def handle_event("restore_user", _params, socket) do
    case Accounts.restore_user(socket.assigns.user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User restored. PII was already scrubbed and cannot be recovered.")
         |> assign(user: user)}

      {:error, :not_deleted} ->
        {:noreply, put_flash(socket, :error, "User is not deleted.")}

      {:error, :window_expired} ->
        {:noreply, put_flash(socket, :error, "Restore window has expired.")}
    end
  end

  def handle_event("hard_delete_user", _params, socket) do
    case Accounts.hard_delete_user(socket.assigns.user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User hard-deleted.")
         |> redirect(to: ~p"/admin/users")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Cannot hard-delete a superadmin.")}

      {:error, _, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete user.")}
    end
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <a href={~p"/admin/users"} class="text-sm text-brand-600 hover:underline mb-4 inline-block">
        &larr; Back to users
      </a>

      <div class="flex items-center justify-between mb-6 gap-4 flex-wrap">
        <h1 class="text-2xl font-bold text-zinc-900">
          {@user.username}
          <span :if={@user.deleted_at} class="ml-2 text-sm font-medium text-red-700">
            (deleted {Calendar.strftime(@user.deleted_at, "%Y-%m-%d")})
          </span>
        </h1>

        <div :if={@user.role != "superadmin"} class="flex gap-2">
          <button
            :if={is_nil(@user.deleted_at)}
            phx-click="soft_delete_user"
            data-confirm={"Soft-delete #{@user.username}? PII will be scrubbed. Restorable for 30 days."}
            class="rounded-lg bg-amber-600 px-4 py-2 text-sm font-semibold text-white hover:bg-amber-500"
          >
            Soft delete
          </button>

          <button
            :if={@user.deleted_at}
            phx-click="restore_user"
            class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-500"
          >
            Restore
          </button>

          <button
            phx-click="hard_delete_user"
            data-confirm={"HARD-delete #{@user.username}? Removes all data (ratings, feedback) irreversibly."}
            class="rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:bg-red-500"
          >
            Hard delete
          </button>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <.stat_card label="Ratings" value={@stats.rating_count} />
        <.stat_card label="Avg Score" value={format_float(@stats.average_score)} />
        <.stat_card label="Highest" value={format_float(@stats.highest_score)} />
        <.stat_card label="Lowest" value={format_float(@stats.lowest_score)} />
      </div>

      <div class="rounded-lg border border-zinc-200 p-4 mb-8">
        <dl class="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
          <div>
            <dt class="text-zinc-500">Email</dt>
            <dd class="font-medium text-zinc-900">{@user.email}</dd>
          </div>
          <div>
            <dt class="text-zinc-500">Role</dt>
            <dd class="font-medium text-zinc-900">{@user.role}</dd>
          </div>
          <div>
            <dt class="text-zinc-500">Joined</dt>
            <dd class="font-medium text-zinc-900">
              {Calendar.strftime(@user.inserted_at, "%Y-%m-%d %H:%M")}
            </dd>
          </div>
        </dl>
      </div>

      <h2 class="text-lg font-bold text-zinc-900 mb-4">Ratings ({length(@ratings)})</h2>

      <div :if={@ratings == []} class="text-sm text-zinc-500">
        No ratings yet.
      </div>

      <div :if={@ratings != []} class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-zinc-200 text-left">
              <th class="pb-3 pr-4 font-medium text-zinc-500">Game</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">Score</th>
              <th class="pb-3 font-medium text-zinc-500">Date</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={rating <- @ratings} class="border-b border-zinc-100">
              <td class="py-3 pr-4 font-medium text-zinc-900">{rating.board_game.name}</td>
              <td class="py-3 pr-4 text-zinc-600">{Float.round(rating.score, 1)}</td>
              <td class="py-3 text-zinc-500">
                {Calendar.strftime(rating.updated_at, "%Y-%m-%d")}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 p-4">
      <p class="text-xs text-zinc-500">{@label}</p>
      <p class="text-2xl font-bold text-zinc-900">{@value}</p>
    </div>
    """
  end

  defp format_float(nil), do: "-"
  defp format_float(val), do: :erlang.float_to_binary(val / 1, decimals: 1)
end
