defmodule Recco.Workers.RefreshEmbeddingsTest do
  use Recco.DataCase, async: true

  alias Recco.Workers.RefreshEmbeddings

  test "triggers a refresh via the recommender client" do
    assert :ok = RefreshEmbeddings.perform(%Oban.Job{})
  end
end
