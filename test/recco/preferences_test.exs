defmodule Recco.PreferencesTest do
  use Recco.DataCase, async: true

  alias Recco.Preferences

  describe "upsert_preferences/2" do
    test "creates preferences for a user" do
      user = insert(:user)

      assert {:ok, pref} =
               Preferences.upsert_preferences(user.id, %{min_players: 2, max_players: 4})

      assert pref.min_players == 2
      assert pref.max_players == 4
    end

    test "updates existing preferences" do
      user = insert(:user)

      assert {:ok, _} = Preferences.upsert_preferences(user.id, %{min_players: 2})
      assert {:ok, pref} = Preferences.upsert_preferences(user.id, %{min_players: 3})
      assert pref.min_players == 3
    end
  end

  describe "get_preferences/1" do
    test "returns nil when no preferences exist" do
      user = insert(:user)
      assert is_nil(Preferences.get_preferences(user.id))
    end

    test "returns existing preferences" do
      user = insert(:user)
      {:ok, _} = Preferences.upsert_preferences(user.id, %{min_players: 2})

      pref = Preferences.get_preferences(user.id)
      assert pref.min_players == 2
    end
  end
end
