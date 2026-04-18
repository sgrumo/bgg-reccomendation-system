defmodule ReccoWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Sets a CSP plus adjacent security headers on browser responses. Runs
  AFTER Phoenix's `put_secure_browser_headers` so it augments (not
  replaces) the Phoenix defaults.

  CSP mode is read at call time from `config :recco, :csp_mode` and
  defaults to `:enforce`. Use `:report_only` in prod for the first week
  of a rollout; violation reports go to `POST /api/csp-report`.
  """

  import Plug.Conn

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    conn
    |> put_resp_header(csp_header_name(), csp_value(conn))
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header(
      "permissions-policy",
      "camera=(), microphone=(), geolocation=(), interest-cohort=()"
    )
    |> maybe_put_hsts()
  end

  defp csp_header_name do
    case mode() do
      :report_only -> "content-security-policy-report-only"
      _ -> "content-security-policy"
    end
  end

  defp csp_value(conn) do
    connect_src =
      case Application.get_env(:recco, :env, :prod) do
        :dev -> "'self' ws: wss: http: https:"
        _ -> "'self' ws: wss:"
      end

    [
      "default-src 'self'",
      "script-src 'self'",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' https://fonts.gstatic.com",
      "img-src 'self' data: https:",
      "connect-src #{connect_src}",
      "frame-ancestors 'none'",
      "form-action 'self'",
      "base-uri 'self'",
      "object-src 'none'",
      "report-uri #{report_uri(conn)}"
    ]
    |> Enum.join("; ")
  end

  defp report_uri(conn) do
    "#{conn.scheme}://#{conn.host}#{report_path()}"
  end

  defp report_path, do: "/api/csp-report"

  defp maybe_put_hsts(conn) do
    case {Application.get_env(:recco, :env, :prod), conn.scheme} do
      {:prod, :https} ->
        put_resp_header(conn, "strict-transport-security", "max-age=31536000; includeSubDomains")

      _ ->
        conn
    end
  end

  defp mode, do: Application.get_env(:recco, :csp_mode, :enforce)
end
