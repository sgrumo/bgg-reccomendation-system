defmodule ReccoWeb.Live.AuthHook do
  @moduledoc false

  import Phoenix.LiveView
  import Phoenix.Component

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, session, socket) do
    case session do
      %{"current_user_id" => user_id} when is_binary(user_id) ->
        {:cont, assign(socket, :current_user_id, user_id)}

      _ ->
        {:halt, redirect(socket, to: "/")}
    end
  end
end
