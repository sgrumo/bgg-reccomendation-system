defmodule ReccoWeb.ConfirmationLive do
  use ReccoWeb, :live_view

  alias Recco.Accounts

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.confirm_user_by_token(token) do
      {:ok, _user} ->
        {:ok,
         socket
         |> put_flash(:info, gettext("Email confirmed. Thanks!"))
         |> redirect(to: post_confirm_path(socket))}

      {:error, :invalid_token} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Confirmation link is invalid or has expired."))
         |> redirect(to: ~p"/confirm")}
    end
  end

  defp post_confirm_path(socket) do
    if socket.assigns[:current_user], do: ~p"/", else: ~p"/login"
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns), do: ~H""
end
