defmodule Recco.Notifications.Discord.Client do
  @moduledoc """
  Behaviour for Discord webhook clients. Swap implementations via
  `config :recco, :discord_client, ...`.
  """

  @callback post(url :: String.t(), payload :: map()) :: :ok | {:error, term()}
end
