defmodule ReccoWeb.Plugs.RateLimitTest do
  use ReccoWeb.ConnCase, async: false

  setup do
    restore = Application.get_env(:recco, Recco.Accounts.RateLimit)

    Application.put_env(:recco, Recco.Accounts.RateLimit,
      login_ip_limit: 2,
      login_ip_scale_ms: 60_000,
      register_ip_limit: 2,
      register_ip_scale_ms: 60_000,
      login_account_limit: 100,
      login_account_scale_ms: 60_000
    )

    reset_rate_limit()

    on_exit(fn ->
      reset_rate_limit()
      Application.put_env(:recco, Recco.Accounts.RateLimit, restore)
    end)

    :ok
  end

  describe "POST /login" do
    test "returns 429 after IP limit is exceeded", %{conn: conn} do
      conn_fn = fn ->
        build_conn()
        |> put_req_header("x-forwarded-for", "10.10.10.10")
        |> post(~p"/login", %{"user" => %{"email" => "x@example.com", "password" => "wrong"}})
      end

      _ = conn_fn.()
      _ = conn_fn.()
      blocked = conn_fn.()

      assert blocked.status == 429
      [retry_after] = get_resp_header(blocked, "retry-after")
      assert String.to_integer(retry_after) > 0
      assert html_response(blocked, 429) =~ "Too many attempts"
      # sanity check that the unrelated default conn wasn't consumed
      assert conn.method == "GET"
    end

    test "429 response renders the login form", %{conn: _conn} do
      build_conn()
      |> put_req_header("x-forwarded-for", "10.10.10.11")
      |> post(~p"/login", %{"user" => %{"email" => "x@example.com", "password" => "x"}})

      build_conn()
      |> put_req_header("x-forwarded-for", "10.10.10.11")
      |> post(~p"/login", %{"user" => %{"email" => "x@example.com", "password" => "x"}})

      blocked =
        build_conn()
        |> put_req_header("x-forwarded-for", "10.10.10.11")
        |> post(~p"/login", %{"user" => %{"email" => "x@example.com", "password" => "x"}})

      assert html_response(blocked, 429) =~ "Sign in"
    end
  end

  describe "POST /register" do
    test "returns 429 after IP limit is exceeded" do
      post_register = fn ->
        build_conn()
        |> put_req_header("x-forwarded-for", "10.10.10.20")
        |> post(~p"/register", %{
          "user" => %{"email" => "x@example.com", "username" => "x", "password" => "x"}
        })
      end

      _ = post_register.()
      _ = post_register.()
      blocked = post_register.()

      assert blocked.status == 429
      assert html_response(blocked, 429) =~ "Create an account"
    end
  end
end
