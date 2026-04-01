defmodule AverzianoWeb.FallbackController do
  use AverzianoWeb, :controller

  @status_map %{
    bad_request: 400,
    unauthorized: 401,
    forbidden: 403,
    not_found: 404,
    conflict: 409,
    unprocessable_entity: 422,
    internal_server_error: 500
  }

  @spec call(Plug.Conn.t(), {:error, atom()} | {:error, atom(), String.t()}) :: Plug.Conn.t()
  def call(conn, {:error, reason}) when is_map_key(@status_map, reason) do
    status = Map.fetch!(@status_map, reason)

    conn
    |> put_status(status)
    |> put_view(json: AverzianoWeb.ErrorJSON)
    |> render("#{status}.json")
  end

  def call(conn, {:error, reason, message}) when is_map_key(@status_map, reason) do
    status = Map.fetch!(@status_map, reason)

    conn
    |> put_status(status)
    |> json(%{errors: %{detail: message}})
  end
end
