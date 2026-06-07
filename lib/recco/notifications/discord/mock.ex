defmodule Recco.Notifications.Discord.Mock do
  @moduledoc """
  Test mock for the Discord client. Sends a `{:discord_notify, url, payload}`
  message back to the test process (resolved from `$callers` so it works when
  invoked inside a `Task.Supervisor` child).
  """

  @behaviour Recco.Notifications.Discord.Client

  @impl true
  @spec post(String.t(), map()) :: :ok
  def post(url, payload) do
    target =
      case Process.get(:"$callers") do
        [pid | _] when is_pid(pid) -> pid
        _ -> self()
      end

    send(target, {:discord_notify, url, payload})
    :ok
  end
end
