defmodule Recco.Repo.Migrations.AddBlockedAtToPrototypes do
  use Ecto.Migration

  def change do
    alter table(:prototypes) do
      add :blocked_at, :utc_datetime
    end
  end
end
