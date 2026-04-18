defmodule ReccoWeb.Presence do
  @moduledoc """
  Phoenix.Presence tracker backed by `Recco.PubSub`. Used to show which
  superadmin is viewing which admin page in near-real-time.
  """

  use Phoenix.Presence,
    otp_app: :recco,
    pubsub_server: Recco.PubSub
end
