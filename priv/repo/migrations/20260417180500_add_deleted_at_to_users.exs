defmodule Recco.Repo.Migrations.AddDeletedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :deleted_at, :utc_datetime
    end

    # Partial index on active users — cheap to query for "is this
    # account live?" without including tombstones.
    create index(:users, [:id], name: :users_active_idx, where: "deleted_at IS NULL")
  end
end
