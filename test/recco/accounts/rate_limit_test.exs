defmodule Recco.Accounts.RateLimitTest do
  use ExUnit.Case, async: false

  alias Recco.Accounts.RateLimit

  @scopes [:login_ip, :register_ip, :login_account]

  setup do
    restore = Application.get_env(:recco, Recco.Accounts.RateLimit)

    Application.put_env(:recco, Recco.Accounts.RateLimit,
      login_ip_limit: 3,
      login_ip_scale_ms: 60_000,
      register_ip_limit: 3,
      register_ip_scale_ms: 60_000,
      login_account_limit: 3,
      login_account_scale_ms: 60_000
    )

    key = "rl-test-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      Enum.each(@scopes, &RateLimit.clear(&1, key))
      Application.put_env(:recco, Recco.Accounts.RateLimit, restore)
    end)

    %{key: key}
  end

  describe "hit/2" do
    test "allows up to limit then denies", %{key: key} do
      assert :allow = RateLimit.hit(:login_ip, key)
      assert :allow = RateLimit.hit(:login_ip, key)
      assert :allow = RateLimit.hit(:login_ip, key)
      assert {:deny, retry_ms} = RateLimit.hit(:login_ip, key)
      assert retry_ms > 0
    end

    test "separates buckets by scope", %{key: key} do
      for _ <- 1..3, do: assert(:allow = RateLimit.hit(:login_ip, key))
      assert {:deny, _} = RateLimit.hit(:login_ip, key)

      assert :allow = RateLimit.hit(:register_ip, key)
    end
  end

  describe "peek/2 + record_failure/2" do
    test "peek does not count against the bucket", %{key: key} do
      for _ <- 1..5, do: assert(:allow = RateLimit.peek(:login_account, key))
    end

    test "record_failure bumps counter and peek reflects it", %{key: key} do
      for _ <- 1..3, do: RateLimit.record_failure(:login_account, key)
      assert {:deny, _} = RateLimit.peek(:login_account, key)
    end

    test "clear/2 resets the bucket", %{key: key} do
      for _ <- 1..3, do: RateLimit.record_failure(:login_account, key)
      assert {:deny, _} = RateLimit.peek(:login_account, key)

      RateLimit.clear(:login_account, key)
      assert :allow = RateLimit.peek(:login_account, key)
    end
  end
end
