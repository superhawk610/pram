defmodule Pram.Repo do
  use Ecto.Repo,
    otp_app: :pram,
    adapter: Ecto.Adapters.Postgres
end
