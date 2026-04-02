defmodule Recco.Repo.Migrations.AddTelemetryUiEventsTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    TelemetryUI.Backend.EctoPostgres.Migrations.up()
  end

  def down do
    TelemetryUI.Backend.EctoPostgres.Migrations.down()
  end
end
