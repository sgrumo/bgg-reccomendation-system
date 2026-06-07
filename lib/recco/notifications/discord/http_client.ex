defmodule Recco.Notifications.Discord.HttpClient do
  @moduledoc """
  Posts JSON payloads to a Discord webhook URL via Req.
  """

  @behaviour Recco.Notifications.Discord.Client

  @impl true
  @spec post(String.t(), map()) :: :ok | {:error, term()}
  def post(url, payload) do
    case Req.post(url, json: payload) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {:http, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
