defmodule Recco.BoardGamesSearchFallbackTest do
  @moduledoc """
  Isolated (async: false) because it flips `:search_strategy` via
  `Application.put_env`, which is global state.
  """
  use Recco.DataCase, async: false

  alias Recco.BoardGames

  setup do
    restore = Application.fetch_env(:recco, :search_strategy)
    Application.put_env(:recco, :search_strategy, :ilike)

    on_exit(fn ->
      case restore do
        {:ok, value} -> Application.put_env(:recco, :search_strategy, value)
        :error -> Application.delete_env(:recco, :search_strategy)
      end
    end)

    :ok
  end

  test "falls back to ilike when strategy is flipped" do
    insert(:board_game, name: "Catan")
    insert(:board_game, name: "Pandemic")

    %{games: games} = BoardGames.list_board_games(%{search: "cat"})

    assert Enum.map(games, & &1.name) == ["Catan"]
  end
end
