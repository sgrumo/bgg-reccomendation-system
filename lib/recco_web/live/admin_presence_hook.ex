defmodule ReccoWeb.Live.AdminPresenceHook do
  @moduledoc """
  `on_mount` hook that tracks the current superadmin on a shared
  `admin:presence` topic and keeps a `@present_admins` assign up-to-date
  via a `:handle_info` hook. Assumes `:current_user` is already assigned
  by the user_auth hook chain — place this hook AFTER `:ensure_superadmin`.

  Section tracking: re-tracks on each `handle_params` so the indicator
  reflects the admin's current page (dashboard / users / jobs / ...).
  """

  import Phoenix.Component
  import Phoenix.LiveView

  alias ReccoWeb.Presence

  @topic "admin:presence"

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:present_admins, %{})
      |> attach_hook(:admin_presence_params, :handle_params, &__MODULE__.handle_params_hook/3)
      |> attach_hook(:admin_presence_info, :handle_info, &__MODULE__.handle_info_hook/2)

    if connected?(socket), do: subscribe_and_track(socket)

    {:cont, assign(socket, :present_admins, current_presence())}
  end

  @spec handle_params_hook(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def handle_params_hook(_params, uri, socket) do
    if connected?(socket), do: update_tracking(socket, uri)
    {:cont, socket}
  end

  @spec handle_info_hook(term(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}
  def handle_info_hook(%{event: "presence_diff"}, socket) do
    {:halt, assign(socket, :present_admins, current_presence())}
  end

  def handle_info_hook(_msg, socket), do: {:cont, socket}

  defp subscribe_and_track(socket) do
    Phoenix.PubSub.subscribe(Recco.PubSub, @topic)

    user = socket.assigns.current_user
    # `key` is per-session so multiple tabs from the same admin appear
    # once each; we still group by username in the UI.
    key = "#{user.id}:#{socket.id}"

    {:ok, _ref} =
      Presence.track(self(), @topic, key, %{
        user_id: user.id,
        username: user.username,
        section: "dashboard",
        joined_at: System.os_time(:second)
      })

    :ok
  end

  defp update_tracking(socket, uri) do
    user = socket.assigns.current_user
    key = "#{user.id}:#{socket.id}"
    section = section_from_uri(uri)

    Presence.update(self(), @topic, key, fn meta -> Map.put(meta, :section, section) end)

    :ok
  end

  defp current_presence, do: Presence.list(@topic)

  defp section_from_uri(uri) do
    case URI.parse(uri).path do
      "/admin" -> "dashboard"
      "/admin/" -> "dashboard"
      "/admin/users" <> _ -> "users"
      "/admin/jobs" <> _ -> "jobs"
      "/admin/crawler" <> _ -> "crawler"
      "/admin/feedback" <> _ -> "feedback"
      _ -> "other"
    end
  end
end
