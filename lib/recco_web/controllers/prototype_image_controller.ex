defmodule ReccoWeb.PrototypeImageController do
  use ReccoWeb, :html_controller

  alias Recco.Prototypes.PrototypeImage
  alias Recco.Prototypes.Storage
  alias Recco.Repo

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(%Plug.Conn{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> halt()
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(PrototypeImage, id) do
      nil ->
        conn |> put_status(:not_found) |> halt()

      %PrototypeImage{path: path, original_filename: filename} ->
        absolute = Storage.absolute_path(path)

        if File.regular?(absolute) do
          conn
          |> put_resp_content_type(content_type(filename))
          |> put_resp_header("cache-control", "private, max-age=86400")
          |> Plug.Conn.send_file(200, absolute)
        else
          conn |> put_status(:not_found) |> halt()
        end
    end
  end

  defp content_type(filename) do
    case filename |> Path.extname() |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".webp" -> "image/webp"
      ".gif" -> "image/gif"
      _ -> "application/octet-stream"
    end
  end
end
