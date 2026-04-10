defmodule ReccoWeb.Live.UserAuth do
  @moduledoc """
  LiveView on_mount hooks for authentication.
  """

  use ReccoWeb, :verified_routes

  import Phoenix.LiveView
  import Phoenix.Component

  alias Recco.Accounts

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: ~p"/login")}
    end
  end

  def on_mount(:ensure_superadmin, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user && Accounts.superadmin?(socket.assigns.current_user) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, redirect(socket, to: ~p"/")}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    assign_new(socket, :current_user, fn ->
      token = session["user_token"]
      token && Accounts.get_user_by_session_token(token)
    end)
  end
end
