defmodule Recco.Notifications.DiscordTest do
  use ExUnit.Case, async: false

  alias Recco.Notifications.Discord

  setup do
    original_url = Application.get_env(:recco, :discord_webhook_url)
    on_exit(fn -> Application.put_env(:recco, :discord_webhook_url, original_url) end)
    :ok
  end

  describe "notify/1" do
    test "delivers the payload to the configured webhook URL" do
      Application.put_env(:recco, :discord_webhook_url, "https://discord.test/webhook")

      Discord.notify(%{content: "hello"})

      assert_receive {:discord_notify, "https://discord.test/webhook", %{content: "hello"}}, 500
    end

    test "is a no-op when no webhook URL is configured" do
      Application.put_env(:recco, :discord_webhook_url, nil)

      Discord.notify(%{content: "hello"})

      refute_receive {:discord_notify, _, _}, 100
    end

    test "is a no-op when the webhook URL is an empty string" do
      Application.put_env(:recco, :discord_webhook_url, "")

      Discord.notify(%{content: "hello"})

      refute_receive {:discord_notify, _, _}, 100
    end
  end
end
