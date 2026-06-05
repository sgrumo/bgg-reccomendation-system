defmodule Recco.Prototypes do
  @moduledoc """
  The Prototypes context — user-submitted board game prototypes with
  collaborators and image galleries.
  """

  import Ecto.Changeset, only: [add_error: 3, get_field: 2]
  import Ecto.Query

  alias Recco.Accounts.User
  alias Recco.BoardGames
  alias Recco.Errors
  alias Recco.Prototypes.Prototype
  alias Recco.Prototypes.PrototypeImage
  alias Recco.Prototypes.Storage
  alias Recco.Repo

  @type list_opts :: %{
          optional(:page) => pos_integer(),
          optional(:per_page) => pos_integer(),
          optional(:user_id) => String.t()
        }

  @default_per_page 24

  @spec list_prototypes(list_opts()) :: %{prototypes: [Prototype.t()], total: non_neg_integer()}
  def list_prototypes(opts \\ %{}) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, @default_per_page)

    base =
      from(p in Prototype,
        order_by: [desc: p.inserted_at],
        preload: [:user, :images]
      )

    filtered =
      case Map.get(opts, :user_id) do
        nil -> base
        user_id -> from(p in base, where: p.user_id == ^user_id)
      end

    total = filtered |> exclude(:preload) |> Repo.aggregate(:count)

    prototypes =
      filtered
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{prototypes: prototypes, total: total}
  end

  @spec get_prototype(String.t()) :: {:ok, Prototype.t()} | Errors.t()
  def get_prototype(id) do
    case Repo.get(Prototype, id) do
      nil -> {:error, :not_found}
      prototype -> {:ok, Repo.preload(prototype, [:user, :images])}
    end
  end

  @spec get_prototype!(String.t()) :: Prototype.t()
  def get_prototype!(id) do
    Prototype
    |> Repo.get!(id)
    |> Repo.preload([:user, :images])
  end

  @spec change_prototype(Prototype.t(), map()) :: Ecto.Changeset.t()
  def change_prototype(prototype \\ %Prototype{collaborators: []}, attrs \\ %{}) do
    Prototype.changeset(prototype, attrs)
  end

  @spec create_prototype(User.t(), map()) :: {:ok, Prototype.t()} | Errors.t(map())
  def create_prototype(%User{id: user_id}, attrs) do
    %Prototype{user_id: user_id, collaborators: []}
    |> Prototype.changeset(attrs)
    |> validate_taxonomy()
    |> Repo.insert()
    |> preload_after_write()
    |> Errors.handle_changeset_error()
  end

  @spec update_prototype(Prototype.t(), User.t(), map()) ::
          {:ok, Prototype.t()} | Errors.t() | Errors.t(map())
  def update_prototype(%Prototype{} = prototype, %User{} = user, attrs) do
    if owns?(prototype, user) do
      prototype
      |> Prototype.changeset(attrs)
      |> validate_taxonomy()
      |> Repo.update()
      |> preload_after_write()
      |> Errors.handle_changeset_error()
    else
      {:error, :forbidden}
    end
  end

  @spec delete_prototype(Prototype.t(), User.t()) :: :ok | Errors.t()
  def delete_prototype(%Prototype{} = prototype, %User{} = user) do
    if owns?(prototype, user) do
      Repo.delete!(prototype)
      Storage.delete_prototype_dir(prototype.id)
      :ok
    else
      {:error, :forbidden}
    end
  end

  @spec owns?(Prototype.t(), User.t()) :: boolean()
  def owns?(%Prototype{user_id: user_id}, %User{id: user_id}), do: true
  def owns?(_, _), do: false

  # Image management

  @spec add_image(Prototype.t(), String.t(), String.t()) ::
          {:ok, PrototypeImage.t()} | Errors.t(map())
  def add_image(%Prototype{id: prototype_id}, path, original_filename) do
    position = next_image_position(prototype_id)

    %PrototypeImage{prototype_id: prototype_id}
    |> PrototypeImage.changeset(%{
      path: path,
      original_filename: original_filename,
      position: position
    })
    |> Repo.insert()
    |> Errors.handle_changeset_error()
  end

  @spec delete_image(PrototypeImage.t(), User.t()) :: {:ok, PrototypeImage.t()} | Errors.t()
  def delete_image(%PrototypeImage{} = image, %User{} = user) do
    prototype = Repo.get!(Prototype, image.prototype_id)

    if owns?(prototype, user) do
      deleted = Repo.delete!(image)
      Storage.delete(image.path)
      {:ok, deleted}
    else
      {:error, :forbidden}
    end
  end

  defp next_image_position(prototype_id) do
    from(i in PrototypeImage,
      where: i.prototype_id == ^prototype_id,
      select: max(i.position)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      n -> n + 1
    end
  end

  defp preload_after_write({:ok, prototype}), do: {:ok, Repo.preload(prototype, [:user, :images])}
  defp preload_after_write(other), do: other

  defp validate_taxonomy(changeset) do
    changeset
    |> validate_against_lookup(:categories, BoardGames.list_categories())
    |> validate_against_lookup(:mechanics, BoardGames.list_mechanics())
  end

  defp validate_against_lookup(changeset, field, lookup) do
    submitted = get_field(changeset, field) || []
    valid = MapSet.new(lookup, & &1.name)
    unknown = Enum.reject(submitted, &MapSet.member?(valid, &1))

    case unknown do
      [] ->
        changeset

      [_ | _] ->
        add_error(changeset, field, "contains unknown values: #{Enum.join(unknown, ", ")}")
    end
  end
end
