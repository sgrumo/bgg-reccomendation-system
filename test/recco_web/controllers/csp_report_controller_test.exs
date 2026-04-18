defmodule ReccoWeb.CspReportControllerTest do
  use ReccoWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :warning)
    on_exit(fn -> Logger.configure(level: previous_level) end)
    :ok
  end

  describe "POST /api/csp-report" do
    test "responds 204 and logs violation fields", %{conn: conn} do
      report = %{
        "csp-report" => %{
          "document-uri" => "https://example.com/games",
          "violated-directive" => "script-src",
          "effective-directive" => "script-src",
          "blocked-uri" => "inline"
        }
      }

      log =
        capture_log(fn ->
          conn =
            conn
            |> put_req_header("content-type", "application/reports+json")
            |> post(~p"/api/csp-report", Jason.encode!(report))

          assert response(conn, 204)
        end)

      assert log =~ "CSP violation"
      assert log =~ "script-src"
      assert log =~ "inline"
    end

    test "handles application/csp-report bodies that bypass Plug.Parsers.JSON", %{conn: conn} do
      raw = ~s({"csp-report":{"violated-directive":"img-src","blocked-uri":"https://evil.tld"}})

      log =
        capture_log(fn ->
          conn =
            conn
            |> put_req_header("content-type", "application/csp-report")
            |> post(~p"/api/csp-report", raw)

          assert response(conn, 204)
        end)

      assert log =~ "CSP violation"
      assert log =~ "img-src"
      assert log =~ "evil.tld"
    end

    test "tolerates an empty/malformed report body", %{conn: conn} do
      log =
        capture_log(fn ->
          conn =
            conn
            |> put_req_header("content-type", "application/csp-report")
            |> post(~p"/api/csp-report", "")

          assert response(conn, 204)
        end)

      assert log =~ "CSP violation"
    end
  end

  describe "browser routes" do
    test "login page emits the CSP header", %{conn: conn} do
      conn = get(conn, ~p"/login")

      [csp] = get_resp_header(conn, "content-security-policy")
      assert csp =~ "default-src 'self'"
      assert csp =~ "report-uri"
    end
  end
end
