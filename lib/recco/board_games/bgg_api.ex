defmodule Recco.BoardGames.BggApi do
  import SweetXml

  @base_url "https://boardgamegeek.com/xmlapi2"

  @spec fetch_board_games([integer()]) :: {:ok, [map()]} | {:error, term()}
  def fetch_board_games(ids) when is_list(ids) do
    ids_param = Enum.join(ids, ",")
    url = "#{@base_url}/thing?id=#{ids_param}&type=boardgame&stats=1"

    case http_get(url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, parse_board_games(body)}

      {:ok, %{status: 202}} ->
        {:error, :queued}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec parse_board_games(binary()) :: [map()]
  def parse_board_games(xml) do
    xml
    |> xpath(~x"//item"l)
    |> Enum.map(&parse_item/1)
  end

  defp parse_item(item) do
    Map.merge(parse_core_fields(item), parse_statistics(item))
    |> Map.merge(parse_all_links(item))
  end

  defp parse_core_fields(item) do
    %{
      bgg_id: xpath(item, ~x"./@id"i),
      name: xpath(item, ~x"./name[@type='primary']/@value"s),
      alternate_names: xpath(item, ~x"./name[@type='alternate']/@value"ls),
      description: xpath(item, ~x"./description/text()"s),
      year_published: xpath_optional_int(item, ~x"./yearpublished/@value"s),
      min_players: xpath_optional_int(item, ~x"./minplayers/@value"s),
      max_players: xpath_optional_int(item, ~x"./maxplayers/@value"s),
      min_playtime: xpath_optional_int(item, ~x"./minplaytime/@value"s),
      max_playtime: xpath_optional_int(item, ~x"./maxplaytime/@value"s),
      playing_time: xpath_optional_int(item, ~x"./playingtime/@value"s),
      min_age: xpath_optional_int(item, ~x"./minage/@value"s),
      image_url: xpath(item, ~x"./image/text()"s) |> nilify_empty(),
      thumbnail_url: xpath(item, ~x"./thumbnail/text()"s) |> nilify_empty()
    }
  end

  defp parse_statistics(item) do
    %{
      average_rating: xpath_optional_float(item, ~x"./statistics/ratings/average/@value"s),
      bayes_average_rating:
        xpath_optional_float(item, ~x"./statistics/ratings/bayesaverage/@value"s),
      users_rated: xpath_optional_int(item, ~x"./statistics/ratings/usersrated/@value"s),
      average_weight: xpath_optional_float(item, ~x"./statistics/ratings/averageweight/@value"s),
      ranks: parse_ranks(item)
    }
  end

  defp parse_all_links(item) do
    %{
      categories: parse_links(item, "boardgamecategory"),
      mechanics: parse_links(item, "boardgamemechanic"),
      designers: parse_links(item, "boardgamedesigner"),
      artists: parse_links(item, "boardgameartist"),
      publishers: parse_links(item, "boardgamepublisher"),
      families: parse_links(item, "boardgamefamily")
    }
  end

  defp parse_links(item, type) do
    item
    |> xpath(~x"./link[@type='#{type}']"l)
    |> Enum.map(fn link ->
      %{
        "id" => xpath(link, ~x"./@id"i),
        "value" => xpath(link, ~x"./@value"s)
      }
    end)
  end

  defp parse_ranks(item) do
    item
    |> xpath(~x"./statistics/ratings/ranks/rank"l)
    |> Enum.map(fn rank ->
      %{
        "id" => xpath(rank, ~x"./@id"i),
        "name" => xpath(rank, ~x"./@name"s),
        "friendly_name" => xpath(rank, ~x"./@friendlyname"s),
        "value" => xpath(rank, ~x"./@value"s),
        "bayes_average" => xpath(rank, ~x"./@bayesaverage"s)
      }
    end)
  end

  defp xpath_optional_int(item, xpath_spec) do
    case item |> xpath(xpath_spec) |> Integer.parse() do
      {int, _} -> int
      :error -> nil
    end
  end

  defp xpath_optional_float(item, xpath_spec) do
    case item |> xpath(xpath_spec) |> Float.parse() do
      {float, _} -> float
      :error -> nil
    end
  end

  defp nilify_empty(""), do: nil
  defp nilify_empty(value), do: value

  defp http_get(url) do
    headers = bearer_token_headers()

    Application.get_env(:recco, :bgg_http_client, Req).get(url,
      headers: headers,
      decode_body: false
    )
  end

  defp bearer_token_headers do
    case Application.get_env(:recco, :bgg_bearer_token) do
      nil -> []
      token -> [{"authorization", "Bearer #{token}"}]
    end
  end
end
