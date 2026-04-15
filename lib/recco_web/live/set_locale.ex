defmodule ReccoWeb.Live.SetLocale do
  @moduledoc """
  LiveView on_mount hook to set the Gettext locale from the session.
  """

  import Phoenix.Component

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, session, socket) do
    locale = session["locale"] || "en"
    Gettext.put_locale(ReccoWeb.Gettext, locale)
    {:cont, assign(socket, :locale, locale)}
  end
end
