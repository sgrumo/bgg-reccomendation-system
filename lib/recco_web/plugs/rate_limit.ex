defmodule ReccoWeb.Plugs.RateLimit do
  @moduledoc """
  Per-IP rate limit for auth endpoints. Pass `scope: :login_ip | :register_ip`.

  On deny: responds with 429, a `retry-after` header (seconds), and renders
  the corresponding auth form with a localized error message — so the
  browser-based login/register flow degrades gracefully instead of
  bouncing the user to a JSON error page.
  """

  import Plug.Conn

  alias Phoenix.Component
  alias Phoenix.Controller
  alias Recco.Accounts.{RateLimit, User}

  @valid_scopes [:login_ip, :register_ip]

  @spec init(keyword()) :: keyword()
  def init(opts) do
    scope = Keyword.fetch!(opts, :scope)
    unless scope in @valid_scopes, do: raise("invalid rate limit scope: #{scope}")
    opts
  end

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, opts) do
    scope = Keyword.fetch!(opts, :scope)
    ip = client_ip(conn)

    case RateLimit.hit(scope, ip) do
      :allow ->
        conn

      {:deny, retry_ms} ->
        retry_seconds = div(retry_ms, 1000) + 1

        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", Integer.to_string(retry_seconds))
        |> render_denied(scope, retry_seconds)
        |> halt()
    end
  end

  defp render_denied(conn, :login_ip, retry_seconds) do
    conn
    |> Controller.put_view(ReccoWeb.UserSessionHTML)
    |> Controller.render(:new, error_message: too_many_message(retry_seconds))
  end

  defp render_denied(conn, :register_ip, retry_seconds) do
    form =
      %User{}
      |> User.registration_changeset(%{})
      |> Component.to_form()

    conn
    |> Controller.put_flash(:error, too_many_message(retry_seconds))
    |> Controller.put_view(ReccoWeb.UserRegistrationHTML)
    |> Controller.render(:new, form: form)
  end

  defp too_many_message(retry_seconds) do
    Gettext.dgettext(
      ReccoWeb.Gettext,
      "default",
      "Too many attempts. Please try again in %{seconds}s.",
      seconds: retry_seconds
    )
  end

  defp client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [value | _] ->
        value
        |> String.split(",")
        |> List.first()
        |> String.trim()

      _ ->
        conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
