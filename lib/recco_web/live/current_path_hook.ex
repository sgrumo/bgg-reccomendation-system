defmodule ReccoWeb.Live.CurrentPathHook do
  @moduledoc """
  Assigns `:current_path` on every LiveView mount and patch. Used by the
  navbar to highlight the active section. Mirrors `Plug.Conn.request_path`
  for HTTP-rendered pages; this bridges the gap for long-lived LiveView
  connections where `@conn` is not available.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:current_path, nil)
      |> attach_hook(:current_path, :handle_params, &set_current_path/3)

    {:cont, socket}
  end

  defp set_current_path(_params, url, socket) when is_binary(url) do
    %URI{path: path} = URI.parse(url)
    {:cont, assign(socket, :current_path, path)}
  end

  defp set_current_path(_params, _url, socket), do: {:cont, socket}
end
