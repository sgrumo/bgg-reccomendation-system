defmodule Recco.Accounts.RateLimit do
  @moduledoc """
  Auth-specific rate limit helpers. Three buckets:

    * per-IP login attempts (all attempts count)
    * per-IP registration attempts (all attempts count)
    * per-account failed logins (only failures count, to avoid throttling
      legitimate users who sign in successfully)

  Limits are read from application config so the test env can tune them.
  """

  alias Recco.RateLimit

  @type scope :: :login_ip | :register_ip | :login_account
  @type decision :: :allow | {:deny, non_neg_integer()}

  @doc """
  Count this attempt against the bucket and return the decision. Use for
  IP buckets where every attempt should count, regardless of outcome.
  """
  @spec hit(scope(), String.t()) :: decision()
  def hit(scope, key) do
    {limit, scale_ms} = config(scope)
    translate(RateLimit.hit(bucket(scope, key), scale_ms, limit))
  end

  @doc """
  Check the bucket without counting this attempt. Use for the per-account
  pre-check where only failures should bump the counter. Denies as soon as
  the counter has reached `limit`, so `limit: 5` means the 6th attempt is
  blocked after 5 recorded failures.
  """
  @spec peek(scope(), String.t()) :: decision()
  def peek(scope, key) do
    {limit, scale_ms} = config(scope)
    # Pass `limit - 1` so Hammer's internal `count <= limit` check denies
    # as soon as the stored counter reaches the configured limit.
    translate(RateLimit.hit(bucket(scope, key), scale_ms, max(limit - 1, 0), 0))
  end

  @spec record_failure(scope(), String.t()) :: :ok
  def record_failure(scope, key) do
    {_limit, scale_ms} = config(scope)
    _ = RateLimit.inc(bucket(scope, key), scale_ms, 1)
    :ok
  end

  @spec clear(scope(), String.t()) :: :ok
  def clear(scope, key) do
    {_limit, scale_ms} = config(scope)
    _ = RateLimit.set(bucket(scope, key), scale_ms, 0)
    :ok
  end

  defp translate({:allow, _count}), do: :allow
  defp translate({:deny, retry_ms}), do: {:deny, retry_ms}

  defp bucket(scope, key), do: "#{scope}:#{key}"

  defp config(scope) do
    cfg = Application.get_env(:recco, __MODULE__, [])

    case scope do
      :login_ip ->
        {Keyword.get(cfg, :login_ip_limit, 10), Keyword.get(cfg, :login_ip_scale_ms, 60_000)}

      :register_ip ->
        {Keyword.get(cfg, :register_ip_limit, 5), Keyword.get(cfg, :register_ip_scale_ms, 60_000)}

      :login_account ->
        {Keyword.get(cfg, :login_account_limit, 5),
         Keyword.get(cfg, :login_account_scale_ms, 300_000)}
    end
  end
end
