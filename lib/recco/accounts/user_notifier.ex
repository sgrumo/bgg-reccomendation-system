defmodule Recco.Accounts.UserNotifier do
  @moduledoc false

  import Swoosh.Email

  alias Recco.Mailer

  @sender {"Recco", "noreply@recco.app"}

  @spec deliver_reset_password_instructions(Recco.Accounts.User.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_reset_password_instructions(user, url) do
    new()
    |> to(user.email)
    |> from(@sender)
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
end
