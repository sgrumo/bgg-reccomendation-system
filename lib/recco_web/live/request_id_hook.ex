defmodule ReccoWeb.Live.RequestIdHook do
  @moduledoc """
  Generates a UUID for each LiveView mount and writes it to Logger metadata
  under `:live_request_id`. `Plug.RequestId` only runs on HTTP requests — it
  doesn't cover the long-lived WebSocket connection — so this bridges the
  gap so LiveView log lines can be correlated end to end.
  """

  require Logger

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, _session, socket) do
    id = Ecto.UUID.generate()
    Logger.metadata(live_request_id: id)
    {:cont, Phoenix.Component.assign(socket, :live_request_id, id)}
  end
end
