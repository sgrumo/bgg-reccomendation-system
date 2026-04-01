defmodule Averziano.Repo do
  use Ecto.Repo,
    otp_app: :averziano,
    adapter: Ecto.Adapters.Postgres
end
