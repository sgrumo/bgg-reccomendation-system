defmodule ReccoWeb.Admin.PrototypeLive.Index do
  use ReccoWeb, :live_view

  alias Recco.Prototypes

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
    filter = params["filter"] || "all"

    opts =
      %{page: page, per_page: @per_page}
      |> apply_filter(filter)

    %{prototypes: prototypes, total: total} = Prototypes.list_prototypes(opts)
    total_pages = max(ceil(total / @per_page), 1)

    {:noreply,
     assign(socket,
       page_title: "Prototypes",
       prototypes: prototypes,
       total: total,
       page: page,
       total_pages: total_pages,
       filter: filter
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("block", %{"id" => id}, socket) do
    prototype = Prototypes.get_prototype!(id)

    case Prototypes.block_prototype(prototype) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Prototype blocked.")
         |> push_patch(to: current_path(socket))}

      {:error, _, _} ->
        {:noreply, put_flash(socket, :error, "Could not block prototype.")}
    end
  end

  def handle_event("unblock", %{"id" => id}, socket) do
    prototype = Prototypes.get_prototype!(id)

    case Prototypes.unblock_prototype(prototype) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Prototype unblocked.")
         |> push_patch(to: current_path(socket))}

      {:error, _, _} ->
        {:noreply, put_flash(socket, :error, "Could not unblock prototype.")}
    end
  end

  defp current_path(socket) do
    params = %{"filter" => socket.assigns.filter, "page" => socket.assigns.page}
    ~p"/admin/prototypes?#{filter_clean_params(params)}"
  end

  defp filter_clean_params(params) do
    Enum.reject(params, fn {_, v} -> v in [nil, "", "all", 1] end) |> Map.new()
  end

  defp apply_filter(opts, "blocked"), do: Map.put(opts, :only_blocked, true)
  defp apply_filter(opts, "active"), do: opts
  defp apply_filter(opts, _), do: Map.put(opts, :include_blocked, true)

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold text-zinc-900 mb-6">Prototypes</h1>

      <div class="flex gap-2 mb-6">
        <.filter_link current={@filter} value="all" label="All" />
        <.filter_link current={@filter} value="active" label="Active" />
        <.filter_link current={@filter} value="blocked" label="Blocked" />
      </div>

      <p class="text-sm text-zinc-500 mb-4">{@total} prototypes</p>

      <div :if={@prototypes == []} class="text-sm text-zinc-500">
        No prototypes match this filter.
      </div>

      <div :if={@prototypes != []} class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-zinc-200 text-left">
              <th class="pb-3 pr-4 font-medium text-zinc-500">Title</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">Submitted by</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">Categories</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">Created</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">Status</th>
              <th class="pb-3 font-medium text-zinc-500">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={prototype <- @prototypes} class="border-b border-zinc-100">
              <td class="py-3 pr-4 font-medium text-zinc-900">
                <a href={~p"/prototypes/#{prototype.id}"} class="text-brand-600 hover:underline">
                  {prototype.title}
                </a>
              </td>
              <td class="py-3 pr-4 text-zinc-700">
                <div class="font-medium">{prototype.user.username}</div>
                <a
                  href={mailto_link(prototype)}
                  class="text-xs text-brand-600 hover:underline"
                >
                  {prototype.user.email}
                </a>
              </td>
              <td class="py-3 pr-4 text-zinc-600 max-w-xs truncate">
                {Enum.join(prototype.categories, ", ")}
              </td>
              <td class="py-3 pr-4 text-zinc-500">
                {Calendar.strftime(prototype.inserted_at, "%Y-%m-%d")}
              </td>
              <td class="py-3 pr-4">
                <span :if={is_nil(prototype.blocked_at)} class="text-emerald-700 font-medium">
                  Active
                </span>
                <span :if={prototype.blocked_at} class="text-red-700 font-medium">
                  Blocked
                </span>
              </td>
              <td class="py-3 flex gap-2">
                <button
                  :if={is_nil(prototype.blocked_at)}
                  phx-click="block"
                  phx-value-id={prototype.id}
                  data-confirm={"Block #{prototype.title}? It will be hidden from other users."}
                  class="rounded-lg bg-amber-600 px-3 py-1 text-xs font-semibold text-white hover:bg-amber-500"
                >
                  Block
                </button>
                <button
                  :if={prototype.blocked_at}
                  phx-click="unblock"
                  phx-value-id={prototype.id}
                  class="rounded-lg bg-emerald-600 px-3 py-1 text-xs font-semibold text-white hover:bg-emerald-500"
                >
                  Unblock
                </button>
                <a
                  href={mailto_link(prototype)}
                  class="rounded-lg bg-brand-600 px-3 py-1 text-xs font-semibold text-white hover:bg-brand-500"
                >
                  Contact
                </a>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.pagination :if={@total_pages > 1} page={@page} total_pages={@total_pages} filter={@filter} />
    </div>
    """
  end

  attr :current, :string, required: true
  attr :value, :string, required: true
  attr :label, :string, required: true

  defp filter_link(assigns) do
    params = if assigns.value == "all", do: %{}, else: %{"filter" => assigns.value}
    assigns = assign(assigns, :href, ~p"/admin/prototypes?#{params}")

    ~H"""
    <.link
      patch={@href}
      class={[
        "px-3 py-1.5 rounded-lg text-sm font-medium border",
        @current == @value && "bg-brand-600 text-white border-brand-600",
        @current != @value && "bg-white text-zinc-700 border-zinc-200 hover:bg-zinc-50"
      ]}
    >
      {@label}
    </.link>
    """
  end

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :filter, :string, required: true

  defp pagination(assigns) do
    ~H"""
    <nav class="mt-6 flex justify-center gap-2" aria-label="Pagination">
      <.page_link
        :if={@page > 1}
        page={@page - 1}
        filter={@filter}
        label="Previous"
      />
      <.page_link
        :for={p <- page_range(@page, @total_pages)}
        page={p}
        filter={@filter}
        label={to_string(p)}
        current={p == @page}
      />
      <.page_link
        :if={@page < @total_pages}
        page={@page + 1}
        filter={@filter}
        label="Next"
      />
    </nav>
    """
  end

  attr :page, :integer, required: true
  attr :filter, :string, required: true
  attr :label, :string, required: true
  attr :current, :boolean, default: false

  defp page_link(assigns) do
    params =
      %{"page" => assigns.page}
      |> then(&if assigns.filter != "all", do: Map.put(&1, "filter", assigns.filter), else: &1)

    assigns = assign(assigns, :href, ~p"/admin/prototypes?#{params}")

    ~H"""
    <.link
      patch={@href}
      class={[
        "px-3 py-1.5 rounded-lg text-sm font-medium border",
        @current && "bg-brand-600 text-white border-brand-600",
        !@current && "bg-white text-zinc-700 border-zinc-200 hover:bg-zinc-50"
      ]}
    >
      {@label}
    </.link>
    """
  end

  defp page_range(current, total) do
    start = max(1, current - 2)
    finish = min(total, current + 2)
    Enum.to_list(start..finish)
  end

  defp mailto_link(prototype) do
    subject = URI.encode("[Recco] About your prototype: #{prototype.title}")
    "mailto:#{prototype.user.email}?subject=#{subject}"
  end

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end
end
