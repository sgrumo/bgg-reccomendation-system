defmodule Recco.Repo do
  use Ecto.Repo,
    otp_app: :recco,
    adapter: Ecto.Adapters.Postgres
end
