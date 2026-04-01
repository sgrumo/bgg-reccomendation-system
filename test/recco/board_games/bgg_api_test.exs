defmodule Recco.BoardGames.BggApiTest do
  use ExUnit.Case, async: true

  alias Recco.BoardGames.BggApi

  @fixture_path Path.join([__DIR__, "..", "..", "fixtures", "bgg_sample.xml"])

  describe "parse_board_games/1" do
    setup do
      xml = File.read!(@fixture_path)
      {:ok, xml: xml}
    end

    test "parses all items from XML", %{xml: xml} do
      games = BggApi.parse_board_games(xml)
      assert length(games) == 2
    end

    test "parses primary fields correctly", %{xml: xml} do
      [gloomhaven | _] = BggApi.parse_board_games(xml)

      assert gloomhaven.bgg_id == 174_430
      assert gloomhaven.name == "Gloomhaven"
      assert gloomhaven.year_published == 2017
      assert gloomhaven.min_players == 1
      assert gloomhaven.max_players == 4
      assert gloomhaven.playing_time == 120
      assert gloomhaven.min_playtime == 60
      assert gloomhaven.max_playtime == 120
      assert gloomhaven.min_age == 14
    end

    test "parses alternate names", %{xml: xml} do
      [gloomhaven | _] = BggApi.parse_board_games(xml)

      assert "Gloomhaven: Gloomy Edition" in gloomhaven.alternate_names
      assert "Gloomhaven: Alternate" in gloomhaven.alternate_names
    end

    test "parses description", %{xml: xml} do
      [gloomhaven | _] = BggApi.parse_board_games(xml)

      assert gloomhaven.description =~
               "Euro-inspired tactical combat"
    end

    test "parses image URLs", %{xml: xml} do
      [gloomhaven | _] = BggApi.parse_board_games(xml)

      assert gloomhaven.image_url =~ "image.jpg"
      assert gloomhaven.thumbnail_url =~ "thumbnail.jpg"
    end

    test "parses statistics", %{xml: xml} do
      [gloomhaven | _] = BggApi.parse_board_games(xml)

      assert gloomhaven.average_rating == 8.7
      assert gloomhaven.bayes_average_rating == 8.4
      assert gloomhaven.users_rated == 55_000
      assert gloomhaven.average_weight == 3.86
    end

    test "parses categories and mechanics as JSONB-ready maps", %{xml: xml} do
      [gloomhaven | _] = BggApi.parse_board_games(xml)

      assert %{"id" => 1022, "value" => "Adventure"} in gloomhaven.categories
      assert %{"id" => 1020, "value" => "Exploration"} in gloomhaven.categories
      assert %{"id" => 2023, "value" => "Cooperative Game"} in gloomhaven.mechanics
    end

    test "parses designers, artists, publishers, families", %{xml: xml} do
      [gloomhaven | _] = BggApi.parse_board_games(xml)

      assert %{"id" => 69_802, "value" => "Isaac Childres"} in gloomhaven.designers
      assert %{"id" => 77_084, "value" => "Alexandr Elichev"} in gloomhaven.artists
      assert %{"id" => 27_425, "value" => "Cephalofair Games"} in gloomhaven.publishers
      assert %{"id" => 24_281, "value" => "Campaign Games"} in gloomhaven.families
    end

    test "parses ranks", %{xml: xml} do
      [gloomhaven | _] = BggApi.parse_board_games(xml)

      assert length(gloomhaven.ranks) == 2

      board_game_rank =
        Enum.find(gloomhaven.ranks, &(&1["name"] == "boardgame"))

      assert board_game_rank["value"] == "1"
      assert board_game_rank["friendly_name"] == "Board Game Rank"
    end

    test "parses second game correctly", %{xml: xml} do
      [_, catan] = BggApi.parse_board_games(xml)

      assert catan.bgg_id == 13
      assert catan.name == "CATAN"
      assert catan.average_rating == 7.1
      assert "The Settlers of Catan" in catan.alternate_names
    end
  end
end
