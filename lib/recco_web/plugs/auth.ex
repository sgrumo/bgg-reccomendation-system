defmodule ReccoWeb.Plugs.Auth do
  @moduledoc false

  import Plug.Conn

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(conn, _opts) do
    token_verifier = Application.fetch_env!(:recco, :token_verifier)

    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- token_verifier.verify_token(token) do
      assign(conn, :current_user_claims, claims)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{errors: %{detail: "Unauthorized"}})
        |> halt()
    end
  end
end
