defmodule Recco.Prototypes.Storage do
  @moduledoc """
  On-disk storage for prototype images.

  Files are written under a configurable upload root (see `:upload_path` in
  config). Each prototype gets its own subdirectory; filenames are UUIDs so
  user-supplied names can't collide or traverse the path.

  Stored paths in the DB are relative to the upload root, so the root can
  move between environments without rewriting rows.
  """

  @type stored_path :: String.t()

  @allowed_extensions ~w(.jpg .jpeg .png .webp .gif)

  @spec root() :: String.t()
  def root do
    Application.get_env(:recco, :upload_path) ||
      Path.join([:code.priv_dir(:recco), "uploads"])
  end

  @spec allowed_extensions() :: [String.t()]
  def allowed_extensions, do: @allowed_extensions

  @doc """
  Copies `source_path` into the prototype's upload directory.

  Returns the relative path to be stored in the DB.
  """
  @spec store(String.t(), String.t(), String.t()) :: {:ok, stored_path()} | {:error, term()}
  def store(prototype_id, source_path, original_filename) do
    ext = original_filename |> Path.extname() |> String.downcase()

    if ext in @allowed_extensions do
      rel_path = Path.join(["prototypes", prototype_id, "#{Ecto.UUID.generate()}#{ext}"])
      abs_path = Path.join(root(), rel_path)

      with :ok <- File.mkdir_p(Path.dirname(abs_path)),
           :ok <- File.cp(source_path, abs_path) do
        {:ok, rel_path}
      end
    else
      {:error, :unsupported_extension}
    end
  end

  @spec absolute_path(stored_path()) :: String.t()
  def absolute_path(rel_path), do: Path.join(root(), rel_path)

  @spec delete(stored_path()) :: :ok
  def delete(rel_path) do
    _ = File.rm(absolute_path(rel_path))
    :ok
  end

  @spec delete_prototype_dir(String.t()) :: :ok
  def delete_prototype_dir(prototype_id) do
    dir = Path.join([root(), "prototypes", prototype_id])
    _ = File.rm_rf(dir)
    :ok
  end
end
