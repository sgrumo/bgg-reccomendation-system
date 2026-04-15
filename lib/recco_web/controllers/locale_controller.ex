defmodule ReccoWeb.LocaleController do
  use ReccoWeb, :html_controller

  @supported_locales Gettext.known_locales(ReccoWeb.Gettext)

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"locale" => locale}) do
    redirect_to = redirect_path(conn)

    if locale in @supported_locales do
      conn
      |> put_session(:locale, locale)
      |> redirect(to: redirect_to)
    else
      redirect(conn, to: redirect_to)
    end
  end

  defp redirect_path(conn) do
    case get_req_header(conn, "referer") do
      [referer | _] ->
        uri = URI.parse(referer)
        uri.path || "/"

      _ ->
        "/"
    end
  end
end
