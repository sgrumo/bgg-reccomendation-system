defmodule Averziano.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Averziano.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Averziano.DataCase
      import Averziano.Factory
    end
  end

  setup tags do
    Averziano.DataCase.setup_sandbox(tags)
    :ok
  end

  @spec setup_sandbox(map()) :: :ok
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Averziano.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @spec errors_on(Ecto.Changeset.t()) :: %{optional(atom()) => [String.t()]}
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
