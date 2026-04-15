defmodule ReccoWeb.Plugs.SetLocale do
  @moduledoc """
  Detects the user's preferred locale from the Accept-Language header
  and sets it for the current process via Gettext.
  """

  import Plug.Conn

  @behaviour Plug

  @supported_locales Gettext.known_locales(ReccoWeb.Gettext)

  @impl true
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @impl true
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    locale = locale_from_session(conn) || locale_from_header(conn) || "en"
    Gettext.put_locale(ReccoWeb.Gettext, locale)
    assign(conn, :locale, locale)
  end

  defp locale_from_session(conn) do
    locale = get_session(conn, :locale)
    if locale in @supported_locales, do: locale
  end

  defp locale_from_header(conn) do
    conn
    |> get_req_header("accept-language")
    |> parse_accept_language()
  end

  defp parse_accept_language([]), do: nil

  defp parse_accept_language([header | _]) do
    header
    |> String.split(",")
    |> Enum.map(&parse_language_tag/1)
    |> Enum.sort_by(fn {_lang, q} -> q end, :desc)
    |> Enum.find_value(fn {lang, _q} -> if lang in @supported_locales, do: lang end)
  end

  defp parse_language_tag(tag) do
    case String.split(String.trim(tag), ";") do
      [lang] ->
        {normalize_lang(lang), 1.0}

      [lang, quality] ->
        q =
          case Float.parse(String.replace(quality, "q=", "")) do
            {val, _} -> val
            :error -> 0.0
          end

        {normalize_lang(lang), q}
    end
  end

  defp normalize_lang(lang) do
    lang |> String.trim() |> String.downcase() |> String.split("-") |> hd()
  end
end
