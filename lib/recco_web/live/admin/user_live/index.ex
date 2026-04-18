defmodule ReccoWeb.Admin.UserLive.Index do
  use ReccoWeb, :live_view

  alias Recco.Accounts

  @per_page 20

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    search = params["search"] || ""
    include_deleted = params["deleted"] == "1"

    opts =
      %{page: page, per_page: @per_page, include_deleted: include_deleted}
      |> maybe_put(:search, search)

    %{users: users, total: total} = Accounts.list_users(opts)
    total_pages = max(ceil(total / @per_page), 1)

    {:noreply,
     assign(socket,
       page_title: "Users",
       users: users,
       total: total,
       page: page,
       total_pages: total_pages,
       search: search,
       include_deleted: include_deleted
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("search", %{"search" => search}, socket) do
    params = if search == "", do: %{}, else: %{"search" => search}
    {:noreply, push_patch(socket, to: ~p"/admin/users?#{params}")}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold text-zinc-900 mb-6">Users</h1>

      <form phx-change="search" phx-submit="search" class="mb-6 max-w-md">
        <.input
          name="search"
          type="text"
          value={@search}
          placeholder="Search by email or username..."
          phx-debounce="300"
        />
      </form>

      <div class="flex items-center justify-between mb-4">
        <p class="text-sm text-zinc-500">{@total} users</p>
        <a
          href={~p"/admin/users?#{deleted_toggle_params(@include_deleted, @search)}"}
          class="text-sm text-brand-600 hover:underline"
        >
          {if @include_deleted, do: "Hide deleted", else: "Show deleted"}
        </a>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-zinc-200 text-left">
              <th class="pb-3 pr-4 font-medium text-zinc-500">Username</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">Email</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">Role</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">Ratings</th>
              <th class="pb-3 font-medium text-zinc-500">Joined</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={row <- @users}
              class={["border-b border-zinc-100", row.user.deleted_at && "opacity-60"]}
            >
              <td class="py-3 pr-4">
                <a
                  href={~p"/admin/users/#{row.user.id}"}
                  class="font-medium text-zinc-900 hover:underline"
                >
                  {row.user.username}
                </a>
                <span :if={row.user.deleted_at} class="ml-2 text-xs text-red-700">(deleted)</span>
              </td>
              <td class="py-3 pr-4 text-zinc-600">{row.user.email}</td>
              <td class="py-3 pr-4">
                <span class={[
                  "inline-block rounded-full px-2 py-0.5 text-xs font-medium",
                  row.user.role == "superadmin" && "bg-brand-100 text-brand-700",
                  row.user.role == "base" && "bg-zinc-100 text-zinc-600"
                ]}>
                  {row.user.role}
                </span>
              </td>
              <td class="py-3 pr-4 text-zinc-600">{row.rating_count}</td>
              <td class="py-3 text-zinc-500">
                {Calendar.strftime(row.user.inserted_at, "%Y-%m-%d")}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.pagination :if={@total_pages > 1} page={@page} total_pages={@total_pages} search={@search} />
    </div>
    """
  end

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :search, :string, required: true

  defp pagination(assigns) do
    ~H"""
    <nav class="mt-6 flex justify-center gap-2" aria-label="Pagination">
      <.page_link :if={@page > 1} page={@page - 1} search={@search} label="Previous" />

      <.page_link
        :for={p <- max(1, @page - 2)..min(@total_pages, @page + 2)//1}
        page={p}
        search={@search}
        label={to_string(p)}
        current={p == @page}
      />

      <.page_link :if={@page < @total_pages} page={@page + 1} search={@search} label="Next" />
    </nav>
    """
  end

  attr :page, :integer, required: true
  attr :search, :string, required: true
  attr :label, :string, required: true
  attr :current, :boolean, default: false

  defp page_link(assigns) do
    params =
      %{"page" => assigns.page}
      |> maybe_put_str("search", assigns.search)

    assigns = assign(assigns, :href, ~p"/admin/users?#{params}")

    ~H"""
    <a
      href={@href}
      class={[
        "px-3 py-2 text-sm rounded-lg",
        @current && "bg-brand-600 text-white",
        !@current && "text-zinc-600 hover:bg-zinc-100"
      ]}
      aria-current={@current && "page"}
    >
      {@label}
    </a>
    """
  end

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end

  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_str(map, _key, ""), do: map
  defp maybe_put_str(map, key, value), do: Map.put(map, key, value)

  defp deleted_toggle_params(include_deleted, search) do
    %{}
    |> (fn p -> if include_deleted, do: p, else: Map.put(p, "deleted", "1") end).()
    |> maybe_put_str("search", search)
  end
end
