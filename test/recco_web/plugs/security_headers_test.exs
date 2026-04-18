defmodule ReccoWeb.Plugs.SecurityHeadersTest do
  use ReccoWeb.ConnCase, async: false

  alias Plug.Conn
  alias ReccoWeb.Plugs.SecurityHeaders

  setup do
    restore_mode = Application.get_env(:recco, :csp_mode)
    restore_env = Application.get_env(:recco, :env)

    on_exit(fn ->
      Application.put_env(:recco, :csp_mode, restore_mode)
      Application.put_env(:recco, :env, restore_env)
    end)

    :ok
  end

  defp run_plug(conn), do: SecurityHeaders.call(conn, SecurityHeaders.init([]))

  describe "enforce mode" do
    setup do
      Application.put_env(:recco, :csp_mode, :enforce)
      :ok
    end

    test "sets Content-Security-Policy header", %{conn: conn} do
      conn = run_plug(conn)

      [csp] = Conn.get_resp_header(conn, "content-security-policy")
      assert csp =~ "default-src 'self'"
      assert csp =~ "frame-ancestors 'none'"
      assert csp =~ "report-uri"
      assert csp =~ "/api/csp-report"
    end

    test "sets ancillary security headers", %{conn: conn} do
      conn = run_plug(conn)

      assert ["strict-origin-when-cross-origin"] =
               Conn.get_resp_header(conn, "referrer-policy")

      assert [permissions] = Conn.get_resp_header(conn, "permissions-policy")
      assert permissions =~ "camera=()"
      assert permissions =~ "geolocation=()"
    end

    test "does not set the Report-Only header", %{conn: conn} do
      conn = run_plug(conn)
      assert [] = Conn.get_resp_header(conn, "content-security-policy-report-only")
    end
  end

  describe "report-only mode" do
    setup do
      Application.put_env(:recco, :csp_mode, :report_only)
      :ok
    end

    test "sets Report-Only header instead of the enforcing one", %{conn: conn} do
      conn = run_plug(conn)

      assert [_csp] = Conn.get_resp_header(conn, "content-security-policy-report-only")
      assert [] = Conn.get_resp_header(conn, "content-security-policy")
    end
  end

  describe "connect-src" do
    test "widens connect-src in dev (allows http/https too)", %{conn: conn} do
      Application.put_env(:recco, :csp_mode, :enforce)
      Application.put_env(:recco, :env, :dev)

      [csp] = run_plug(conn) |> Conn.get_resp_header("content-security-policy")

      assert csp =~ "connect-src 'self' ws: wss: http: https:"
    end

    test "restricts connect-src in prod (websocket only)", %{conn: conn} do
      Application.put_env(:recco, :csp_mode, :enforce)
      Application.put_env(:recco, :env, :prod)

      [csp] = run_plug(conn) |> Conn.get_resp_header("content-security-policy")

      assert csp =~ "connect-src 'self' ws: wss:"
      refute csp =~ "connect-src 'self' ws: wss: http"
    end
  end
end
