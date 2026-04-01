defmodule Recco.BoardGames.BggApi.MockClient do
  @spec get(String.t(), keyword()) :: {:ok, map()}
  def get(_url, _opts \\ []) do
    xml = File.read!(Path.join([__DIR__, "..", "fixtures", "bgg_sample.xml"]))
    {:ok, %{status: 200, body: xml}}
  end
end
