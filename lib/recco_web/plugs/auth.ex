defmodule ReccoWeb.Plugs.Auth do
  @moduledoc false

  import Plug.Conn

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(conn, _opts) do
    token_verifier = Application.fetch_env!(:recco, :token_verifier)

    :telemetry.span([:recco, :auth, :token], %{}, fn ->
      case authorize(conn, token_verifier) do
        {:ok, updated_conn} -> {updated_conn, %{result: :ok}}
        {:missing, updated_conn} -> {updated_conn, %{result: :missing}}
        {:invalid, updated_conn} -> {updated_conn, %{result: :invalid}}
      end
    end)
  end

  defp authorize(conn, token_verifier) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case token_verifier.verify_token(token) do
          {:ok, claims} -> {:ok, assign(conn, :current_user_claims, claims)}
          _ -> {:invalid, deny(conn)}
        end

      _ ->
        {:missing, deny(conn)}
    end
  end

  defp deny(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{errors: %{detail: "Unauthorized"}})
    |> halt()
  end
end
