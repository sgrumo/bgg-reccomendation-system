defmodule ReccoWeb.CspReportController do
  @moduledoc """
  Receives CSP violation reports and logs them at warning level. Kept
  intentionally small: we just log enough context to understand which
  directive a page tripped. During the Report-Only rollout these logs
  drive tightening/loosening of the policy in
  `ReccoWeb.Plugs.SecurityHeaders`.

  Browsers send `application/csp-report`, which `Plug.Parsers.JSON` does
  not match (it only matches `application/json` and `*+json`), so we
  parse the body ourselves. `application/reports+json` (Reporting API)
  would arrive in `params` directly.
  """
  use ReccoWeb, :controller

  require Logger

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    {report, conn} = extract_report(conn, params)
    log_report(report)
    send_resp(conn, :no_content, "")
  end

  defp extract_report(conn, %{"csp-report" => report}) when is_map(report), do: {report, conn}

  defp extract_report(conn, %{} = params) when map_size(params) > 0, do: {params, conn}

  defp extract_report(conn, _params) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        report =
          case Jason.decode(body) do
            {:ok, %{"csp-report" => r}} when is_map(r) -> r
            {:ok, %{} = r} -> r
            _ -> %{}
          end

        {report, conn}

      {:error, _} ->
        {%{}, conn}
    end
  end

  defp log_report(report) do
    Logger.warning("CSP violation",
      blocked_uri: Map.get(report, "blocked-uri"),
      violated_directive: Map.get(report, "violated-directive"),
      effective_directive: Map.get(report, "effective-directive"),
      document_uri: Map.get(report, "document-uri"),
      source_file: Map.get(report, "source-file"),
      disposition: Map.get(report, "disposition")
    )
  end
end
