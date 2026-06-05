defmodule Recco.Repo.Migrations.CreatePrototypeLikes do
  use Ecto.Migration

  def change do
    create table(:prototype_likes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :prototype_id, references(:prototypes, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:prototype_likes, [:user_id])
    create index(:prototype_likes, [:prototype_id])
    create unique_index(:prototype_likes, [:user_id, :prototype_id])
  end
end
