defmodule Averziano.Factory do
  use ExMachina.Ecto, repo: Averziano.Repo

  # Define factories here as you add schemas. Example:
  #
  # def user_factory do
  #   %Averziano.Accounts.User{
  #     email: sequence(:email, &"user#{&1}@example.com"),
  #     name: "Test User"
  #   }
  # end
end
