defmodule Recco.Notifications.EventsTest do
  use ExUnit.Case, async: true

  alias Recco.Accounts.User
  alias Recco.Notifications.Events
  alias Recco.Prototypes.Prototype

  describe "user_registered/1" do
    test "dispatches an embed containing the username" do
      Events.user_registered(%User{username: "alice"})

      assert_receive {:discord_notify, _url, payload}, 500
      assert [%{title: "New user registered", description: description}] = payload.embeds
      assert description =~ "alice"
    end
  end

  describe "prototype_posted/1" do
    test "dispatches an embed with title, author and play info" do
      prototype = %Prototype{
        title: "Dice & Dragons",
        min_players: 2,
        max_players: 4,
        min_playtime: 30,
        max_playtime: 60,
        user: %User{username: "bob"}
      }

      Events.prototype_posted(prototype)

      assert_receive {:discord_notify, _url, payload}, 500
      assert [embed] = payload.embeds
      assert embed.title == "New prototype posted"
      assert embed.description =~ "Dice & Dragons"
      assert embed.description =~ "bob"
      assert Enum.any?(embed.fields, &(&1.name == "Players" and &1.value == "2–4"))
      assert Enum.any?(embed.fields, &(&1.name == "Playtime" and &1.value == "30–60 min"))
    end

    test "falls back to 'unknown' author when user is not preloaded" do
      prototype = %Prototype{
        title: "Orphan",
        min_players: 1,
        max_players: 2,
        min_playtime: 10,
        max_playtime: 20,
        user: %Ecto.Association.NotLoaded{}
      }

      Events.prototype_posted(prototype)

      assert_receive {:discord_notify, _url, payload}, 500
      assert [%{description: description}] = payload.embeds
      assert description =~ "unknown"
    end
  end
end
