defmodule ReccoWeb.Admin.JobLive do
  use ReccoWeb, :live_view

  import Ecto.Query

  alias Recco.Repo

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, 10_000)

    {:ok, assign(socket, page_title: "Background Jobs", jobs: load_jobs(), stats: load_stats())}
  end

  @impl true
  @spec handle_info(atom(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, 10_000)
    {:noreply, assign(socket, jobs: load_jobs(), stats: load_stats())}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold text-zinc-900 mb-6">Background Jobs</h1>

      <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
        <.job_stat label="Completed" value={@stats[:completed] || 0} color="text-green-600" />
        <.job_stat label="Available" value={@stats[:available] || 0} color="text-blue-600" />
        <.job_stat label="Executing" value={@stats[:executing] || 0} color="text-yellow-600" />
        <.job_stat label="Retryable" value={@stats[:retryable] || 0} color="text-red-600" />
      </div>

      <h2 class="text-lg font-bold text-zinc-900 mb-4">Recent Jobs</h2>

      <div :if={@jobs == []} class="text-sm text-zinc-500">No jobs found.</div>

      <div :if={@jobs != []} class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-zinc-200 text-left">
              <th class="pb-3 pr-4 font-medium text-zinc-500">Worker</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">State</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">Queue</th>
              <th class="pb-3 pr-4 font-medium text-zinc-500">Attempt</th>
              <th class="pb-3 font-medium text-zinc-500">Scheduled</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={job <- @jobs} class="border-b border-zinc-100">
              <td class="py-3 pr-4 font-medium text-zinc-900">{short_worker(job.worker)}</td>
              <td class="py-3 pr-4">
                <span class={[
                  "inline-block rounded-full px-2 py-0.5 text-xs font-medium",
                  state_class(job.state)
                ]}>
                  {job.state}
                </span>
              </td>
              <td class="py-3 pr-4 text-zinc-600">{job.queue}</td>
              <td class="py-3 pr-4 text-zinc-600">{job.attempt}/{job.max_attempts}</td>
              <td class="py-3 text-zinc-500">{format_time(job.scheduled_at)}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="text-xs text-zinc-400 mt-4">Auto-refreshes every 10 seconds.</p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :color, :string, required: true

  defp job_stat(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 p-4">
      <p class="text-xs text-zinc-500">{@label}</p>
      <p class={["text-2xl font-bold", @color]}>{@value}</p>
    </div>
    """
  end

  defp load_jobs do
    from(j in Oban.Job,
      order_by: [desc: j.id],
      limit: 50,
      select: %{
        worker: j.worker,
        state: j.state,
        queue: j.queue,
        attempt: j.attempt,
        max_attempts: j.max_attempts,
        scheduled_at: j.scheduled_at
      }
    )
    |> Repo.all()
  end

  defp load_stats do
    from(j in Oban.Job,
      group_by: j.state,
      select: {j.state, count(j.id)}
    )
    |> Repo.all()
    |> Map.new(fn {state, count} -> {String.to_existing_atom(state), count} end)
  rescue
    ArgumentError -> %{}
  end

  defp short_worker(worker) do
    worker |> String.split(".") |> List.last()
  end

  defp state_class("completed"), do: "bg-green-100 text-green-700"
  defp state_class("available"), do: "bg-blue-100 text-blue-700"
  defp state_class("executing"), do: "bg-yellow-100 text-yellow-700"
  defp state_class("retryable"), do: "bg-red-100 text-red-700"
  defp state_class("scheduled"), do: "bg-zinc-100 text-zinc-600"
  defp state_class(_), do: "bg-zinc-100 text-zinc-600"

  defp format_time(nil), do: "-"

  defp format_time(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end
end
