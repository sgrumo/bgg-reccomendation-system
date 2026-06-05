defmodule ReccoWeb.ForgotPasswordLive do
  use ReccoWeb, :live_view

  alias Recco.Accounts

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: to_form(%{"email" => ""}, as: :user),
       page_title: gettext("Forgot password")
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("submit", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_reset_password_instructions(user, fn token ->
        url(~p"/reset-password/#{token}")
      end)
    end

    socket =
      socket
      |> put_flash(
        :info,
        gettext(
          "If your email is in our system, you will receive instructions to reset your password shortly."
        )
      )
      |> redirect(to: ~p"/login")

    {:noreply, socket}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md mt-16 px-4">
      <div class="panel panel-lg p-8">
        <div class="label mb-2">{gettext("Reset access")}</div>
        <h1 class="text-[clamp(30px,3.6vw,44px)] mb-3">{gettext("Forgot your password?")}</h1>
        <p class="text-ink-soft mb-7">
          {gettext("We'll send a password reset link to your inbox.")}
        </p>

        <.form for={@form} phx-submit="submit">
          <div class="space-y-4">
            <.input field={@form[:email]} type="email" label={gettext("Email")} required />
          </div>

          <button type="submit" class="btn btn-primary btn-lg w-full justify-center mt-6">
            {gettext("Send reset link")} →
          </button>
        </.form>

        <p class="mt-6 text-center text-sm">
          <a href={~p"/login"} class="font-bold underline decoration-2 underline-offset-2">
            {gettext("Back to sign in")}
          </a>
        </p>
      </div>
    </div>
    """
  end
end
