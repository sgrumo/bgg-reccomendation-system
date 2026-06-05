defmodule Recco.Repo.Migrations.CreatePrototypes do
  use Ecto.Migration

  def change do
    create table(:prototypes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :title, :string, null: false
      add :description, :text, null: false
      add :min_players, :integer, null: false
      add :max_players, :integer, null: false
      add :min_playtime, :integer, null: false
      add :max_playtime, :integer, null: false
      add :categories, {:array, :string}, null: false, default: []
      add :mechanics, {:array, :string}, null: false, default: []
      add :collaborators, :jsonb, null: false, default: "[]"
      add :contact_email, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:prototypes, [:user_id])
    create index(:prototypes, [:inserted_at])

    create table(:prototype_images, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :prototype_id, references(:prototypes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :path, :string, null: false
      add :original_filename, :string, null: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:prototype_images, [:prototype_id])
    create index(:prototype_images, [:prototype_id, :position])
  end
end
