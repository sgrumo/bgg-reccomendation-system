defmodule ReccoWeb.UserSessionLockoutTest do
  @moduledoc """
  Isolated (async: false) because it temporarily lowers the per-account
  rate limit via Application.put_env; leaking that to concurrent async
  tests would destabilise them.
  """
  use ReccoWeb.ConnCase, async: false

  setup do
    restore = Application.get_env(:recco, Recco.Accounts.RateLimit)

    Application.put_env(:recco, Recco.Accounts.RateLimit,
      login_ip_limit: 1000,
      login_ip_scale_ms: 60_000,
      register_ip_limit: 1000,
      register_ip_scale_ms: 60_000,
      login_account_limit: 2,
      login_account_scale_ms: 60_000
    )

    reset_rate_limit()

    on_exit(fn ->
      reset_rate_limit()
      Application.put_env(:recco, Recco.Accounts.RateLimit, restore)
    end)

    :ok
  end

  test "locks out after repeated failures for the same account", %{conn: conn} do
    email = "lockout-#{System.unique_integer([:positive])}@example.com"
    insert(:user, email: email)

    attempt = fn ->
      post(conn, ~p"/login", %{"user" => %{"email" => email, "password" => "wrong"}})
    end

    _ = attempt.()
    _ = attempt.()
    locked = attempt.()

    assert locked.status == 429
    assert html_response(locked, 429) =~ "Too many failed attempts"
  end

  test "successful login clears the account bucket", %{conn: conn} do
    email = "clear-#{System.unique_integer([:positive])}@example.com"
    insert(:user, email: email)

    post(conn, ~p"/login", %{"user" => %{"email" => email, "password" => "wrong"}})

    success =
      post(conn, ~p"/login", %{
        "user" => %{"email" => email, "password" => "valid_password123"}
      })

    assert redirected_to(success) == ~p"/"

    again = post(conn, ~p"/login", %{"user" => %{"email" => email, "password" => "wrong"}})
    assert again.status == 200
  end
end
