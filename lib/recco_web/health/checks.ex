defmodule ReccoWeb.Health.Checks do
  @moduledoc false

  @spec database() :: :ok | {:error, String.t()}
  def database do
    case Ecto.Adapters.SQL.query(Recco.Repo, "SELECT 1") do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Database unreachable: #{inspect(reason)}"}
    end
  end
end
