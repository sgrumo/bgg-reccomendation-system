defmodule Recco.Workers.DatabaseBackup do
  @moduledoc """
  Oban worker that creates a compressed PostgreSQL dump.
  Runs weekly (Sundays at 2 AM). Only active when `BACKUP_PATH` is set.
  Retains the last 4 backups and deletes older ones.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @retain 4

  @impl true
  @spec perform(Oban.Job.t()) :: :ok | {:error, String.t()}
  def perform(_job) do
    case Application.get_env(:recco, :backup_path) do
      nil ->
        Logger.info("DatabaseBackup: BACKUP_PATH not set, skipping")
        :ok

      path ->
        run_backup(path)
    end
  end

  @spec run_backup(String.t()) :: :ok | {:error, String.t()}
  defp run_backup(path) do
    File.mkdir_p!(path)

    filename = "recco_#{timestamp()}.dump"
    dest = Path.join(path, filename)
    db_url = build_pg_url()

    Logger.info("DatabaseBackup: starting dump to #{dest}")

    case System.cmd("pg_dump", ["--format=custom", "--dbname=#{db_url}", "--file=#{dest}"],
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        Logger.info("DatabaseBackup: dump complete")
        prune_old_backups(path)
        :ok

      {output, code} ->
        Logger.error("DatabaseBackup: pg_dump exited with #{code}: #{output}")
        {:error, "pg_dump failed (exit #{code}): #{output}"}
    end
  end

  @spec build_pg_url() :: String.t()
  defp build_pg_url do
    Application.fetch_env!(:recco, Recco.Repo)
    |> Keyword.fetch!(:url)
    |> String.replace_leading("ecto://", "postgresql://")
  end

  @spec prune_old_backups(String.t()) :: :ok
  defp prune_old_backups(path) do
    path
    |> File.ls!()
    |> Enum.filter(&String.match?(&1, ~r/^recco_.*\.dump$/))
    |> Enum.sort(:desc)
    |> Enum.drop(@retain)
    |> Enum.each(fn file ->
      full = Path.join(path, file)
      Logger.info("DatabaseBackup: pruning #{full}")
      File.rm!(full)
    end)
  end

  @spec timestamp() :: String.t()
  defp timestamp do
    DateTime.utc_now()
    |> Calendar.strftime("%Y%m%d_%H%M%S")
  end
end
