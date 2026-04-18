defmodule Recco.RateLimit do
  @moduledoc """
  Hammer-backed rate limiter used across the app (auth endpoints today,
  extensible to other surfaces). Holds an ETS table and schedules its own
  cleanup sweep.
  """

  use Hammer, backend: :ets
end
