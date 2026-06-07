defmodule Recco.Accounts.UserNotifier do
  @moduledoc false

  import Swoosh.Email

  alias Recco.Mailer

  @spec deliver_reset_password_instructions(Recco.Accounts.User.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_reset_password_instructions(user, url) do
    new()
    |> to(user.email)
    |> from(sender())
    |> subject("Reset your password")
    |> text_body("""
    Hi #{user.username},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this email.

    The link expires in 1 hour.
    """)
    |> Mailer.deliver()
  end

  @spec deliver_confirmation_instructions(Recco.Accounts.User.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_confirmation_instructions(user, url) do
    new()
    |> to(user.email)
    |> from(sender())
    |> subject("Confirm your email")
    |> text_body("""
    Hi #{user.username},

    Welcome to Recco! Please confirm your email by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this email.

    The link expires in 7 days.
    """)
    |> Mailer.deliver()
  end

  defp sender, do: Application.fetch_env!(:recco, :mailer_sender)
end
