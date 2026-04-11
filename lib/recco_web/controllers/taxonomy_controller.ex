defmodule ReccoWeb.TaxonomyController do
  use ReccoWeb, :controller

  alias Recco.BoardGames

  @spec categories(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def categories(conn, _params) do
    categories =
      BoardGames.list_categories()
      |> Enum.map(&%{id: &1.bgg_id, name: &1.name})

    json(conn, %{data: categories})
  end

  @spec mechanics(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def mechanics(conn, _params) do
    mechanics =
      BoardGames.list_mechanics()
      |> Enum.map(&%{id: &1.bgg_id, name: &1.name})

    json(conn, %{data: mechanics})
  end
end
