defmodule Recco.Errors do
  @type reason ::
          :bad_request
          | :unauthorized
          | :forbidden
          | :not_found
          | :conflict
          | :unprocessable_entity
          | :internal_server_error

  @type t :: {:error, reason()}
  @type t(details) :: {:error, reason(), details}

  @spec handle_changeset_error({:ok, result} | {:error, Ecto.Changeset.t()}) ::
          {:ok, result} | t(map())
        when result: any()
  def handle_changeset_error({:ok, result}), do: {:ok, result}

  def handle_changeset_error({:error, %Ecto.Changeset{} = changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
        Regex.replace(~r"%{(\w+)}", message, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    {:error, :unprocessable_entity, errors}
  end
end
