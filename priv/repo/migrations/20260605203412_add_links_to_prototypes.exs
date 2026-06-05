defmodule Recco.Repo.Migrations.AddLinksToPrototypes do
  use Ecto.Migration

  def change do
    alter table(:prototypes) do
      add :links, :jsonb, null: false, default: "[]"
    end
  end
end
