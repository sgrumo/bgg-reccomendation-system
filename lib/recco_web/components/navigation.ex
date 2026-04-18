defmodule ReccoWeb.Navigation do
  @moduledoc """
  Navigation components: navbar, mobile menu, sidebar, user menu.
  """

  use ReccoWeb, :html

  attr :current_user, :any, default: nil

  @spec navbar(map()) :: Phoenix.LiveView.Rendered.t()
  def navbar(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 border-b-2 border-border bg-bw">
      <nav class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8" aria-label={gettext("Main navigation")}>
        <div class="flex h-16 items-center justify-between">
          <button
            id="mobile-menu-button"
            phx-hook="MobileMenu"
            class="md:hidden rounded-base border-2 border-border p-2 hover:bg-main"
            aria-expanded="false"
            aria-controls="mobile-menu"
            aria-label={gettext("Open menu")}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              class="h-6 w-6"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
              />
            </svg>
          </button>

          <div class="hidden md:flex items-center gap-8">
            <a href={~p"/"} class="text-xl font-bold">BGRecco</a>
            <div class="flex items-center gap-1">
              <.nav_link href={~p"/games"} label={gettext("Browse")} />
              <%= if @current_user do %>
                <.nav_link href={~p"/ratings"} label={gettext("My Ratings")} />
                <.nav_link href={~p"/wishlist"} label={gettext("Wishlist")} />
                <.nav_link href={~p"/recommendations"} label={gettext("For You")} />
              <% end %>
            </div>
          </div>

          <div class="hidden md:flex items-center gap-3">
            <.locale_switcher />
            <.user_menu current_user={@current_user} />
          </div>
        </div>
      </nav>

      <.mobile_menu current_user={@current_user} />
    </header>
    """
  end

  attr :current_user, :any, default: nil

  @spec mobile_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def mobile_menu(assigns) do
    ~H"""
    <div
      id="mobile-menu"
      class="hidden md:hidden fixed inset-0 z-50"
      role="dialog"
      aria-modal="true"
      aria-label={gettext("Mobile navigation")}
    >
      <div
        id="mobile-menu-backdrop"
        class="fixed inset-0 bg-black/40 transition-opacity duration-300 opacity-0"
      >
      </div>
      <div
        id="mobile-menu-panel"
        class="fixed inset-y-0 left-0 w-full max-w-xs border-r-2 border-border bg-bw p-6 overflow-y-auto transition-transform duration-300 -translate-x-full"
      >
        <div class="flex items-center justify-between mb-8">
          <span class="text-lg font-bold">BGRecco</span>
          <button
            id="mobile-menu-close"
            class="rounded-base border-2 border-border p-2 hover:bg-main"
            aria-label={gettext("Close menu")}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              class="h-6 w-6"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <nav class="space-y-2" aria-label={gettext("Mobile navigation")}>
          <a
            href={~p"/games"}
            class="block rounded-base border-2 border-border px-3 py-2 text-base font-bold hover:bg-main"
          >
            {gettext("Browse")}
          </a>

          <%= if @current_user do %>
            <a
              href={~p"/ratings"}
              class="block rounded-base border-2 border-border px-3 py-2 text-base font-bold hover:bg-main"
            >
              {gettext("My Ratings")}
            </a>
            <a
              href={~p"/wishlist"}
              class="block rounded-base border-2 border-border px-3 py-2 text-base font-bold hover:bg-main"
            >
              {gettext("Wishlist")}
            </a>
            <a
              href={~p"/recommendations"}
              class="block rounded-base border-2 border-border px-3 py-2 text-base font-bold hover:bg-main"
            >
              {gettext("For You")}
            </a>
            <div class="border-t-2 border-border pt-4 mt-4">
              <a
                href={~p"/profile"}
                class="block rounded-base border-2 border-border px-3 py-2 text-base font-bold hover:bg-main"
              >
                {@current_user.username} — {gettext("Profile")}
              </a>
            </div>
          <% else %>
            <div class="border-t-2 border-border pt-4 mt-4 space-y-2">
              <a
                href={~p"/login"}
                class="block rounded-base border-2 border-border px-3 py-2 text-base font-bold hover:bg-main"
              >
                {gettext("Sign in")}
              </a>
              <a
                href={~p"/register"}
                class="block rounded-base border-2 border-border bg-main px-3 py-2 text-base font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
              >
                {gettext("Create account")}
              </a>
            </div>
          <% end %>

          <div class="border-t-2 border-border pt-4 mt-4">
            <.locale_switcher />
          </div>
        </nav>
      </div>
    </div>
    """
  end

  attr :current_user, :any, default: nil

  @spec admin_sidebar(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_sidebar(assigns) do
    ~H"""
    <aside
      class="hidden lg:fixed lg:inset-y-0 lg:flex lg:w-64 lg:flex-col"
      aria-label={gettext("Admin sidebar")}
    >
      <div class="flex flex-col flex-grow border-r border-zinc-200 bg-zinc-50 pt-5 pb-4 overflow-y-auto">
        <div class="flex items-center flex-shrink-0 px-4 mb-6">
          <a href={~p"/"} class="text-xl font-bold text-brand-600">BGRecco</a>
          <span class="ml-2 text-xs font-medium text-zinc-500 bg-zinc-200 rounded px-1.5 py-0.5">
            Admin
          </span>
        </div>
        <nav class="flex-1 px-3 space-y-1" aria-label={gettext("Admin navigation")}>
          <.sidebar_link href={~p"/admin"} icon="hero-chart-bar" label={gettext("Dashboard")} />
          <.sidebar_link href={~p"/admin/users"} icon="hero-users" label={gettext("Users")} />
          <.sidebar_link href={~p"/admin/jobs"} icon="hero-queue-list" label={gettext("Jobs")} />
          <.sidebar_link href={~p"/admin/crawler"} icon="hero-arrow-path" label={gettext("Crawler")} />
          <.sidebar_link
            href={~p"/admin/feedback"}
            icon="hero-hand-thumb-up"
            label={gettext("Feedback")}
          />
          <.sidebar_link href={~p"/admin/metrics"} icon="hero-signal" label={gettext("Metrics")} />
          <div class="border-t border-zinc-200 my-3"></div>
          <.sidebar_link href={~p"/"} icon="hero-arrow-left" label={gettext("Back to site")} />
        </nav>
        <div class="flex-shrink-0 border-t border-zinc-200 p-4">
          <p class="text-sm font-medium text-zinc-700">{@current_user.username}</p>
          <p class="text-xs text-zinc-500">{@current_user.email}</p>
        </div>
      </div>
    </aside>
    """
  end

  attr :present_admins, :map, default: %{}

  @spec admin_presence_indicator(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_presence_indicator(assigns) do
    grouped =
      assigns.present_admins
      |> Enum.flat_map(fn {_key, %{metas: metas}} -> metas end)
      |> Enum.uniq_by(& &1.user_id)

    assigns = assign(assigns, :admins, grouped)

    ~H"""
    <div :if={@admins != []} class="mb-4 rounded-lg border border-zinc-200 bg-white p-3">
      <p class="text-xs font-medium text-zinc-500 mb-2">
        Admins online ({length(@admins)})
      </p>
      <ul class="space-y-1">
        <li :for={admin <- @admins} class="flex items-center gap-2 text-xs">
          <span class="inline-block h-2 w-2 rounded-full bg-emerald-500" aria-hidden="true"></span>
          <span class="font-medium text-zinc-900">{admin.username}</span>
          <span class="text-zinc-500">on {admin.section}</span>
        </li>
      </ul>
    </div>
    """
  end

  attr :current_user, :any, required: true

  @spec user_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def user_menu(assigns) do
    ~H"""
    <%= if @current_user do %>
      <div class="flex items-center gap-3">
        <a
          href={~p"/profile"}
          class="rounded-base border-2 border-border bg-bw px-3 py-1.5 text-sm font-bold hover:bg-main transition-colors"
        >
          {@current_user.username}
        </a>
      </div>
    <% else %>
      <div class="flex items-center gap-3">
        <a
          href={~p"/login"}
          class="rounded-base border-2 border-border bg-bw px-3 py-1.5 text-sm font-bold hover:bg-bg transition-colors"
        >
          {gettext("Sign in")}
        </a>
        <a
          href={~p"/register"}
          class="rounded-base border-2 border-border bg-main px-3 py-1.5 text-sm font-bold shadow-brutalist hover:translate-x-shadow-x hover:translate-y-shadow-y hover:shadow-none transition-all"
        >
          {gettext("Create account")}
        </a>
      </div>
    <% end %>
    """
  end

  @locales %{"en" => "EN", "it" => "IT"}

  @spec locale_switcher(map()) :: Phoenix.LiveView.Rendered.t()
  def locale_switcher(assigns) do
    current = Gettext.get_locale(ReccoWeb.Gettext)
    assigns = assign(assigns, current: current, locales: @locales)

    ~H"""
    <div class="flex items-center gap-1">
      <.link
        :for={{code, label} <- @locales}
        href={~p"/locale/#{code}"}
        method="put"
        class={[
          "rounded-base border-2 border-border px-2 py-0.5 text-xs font-bold transition-all",
          code == @current && "bg-main",
          code != @current && "bg-bw hover:bg-bg"
        ]}
        aria-label={label}
        aria-current={code == @current && "true"}
      >
        {label}
      </.link>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true

  defp nav_link(assigns) do
    ~H"""
    <a href={@href} class="rounded-base px-3 py-1.5 text-sm font-bold hover:bg-main transition-colors">
      {@label}
    </a>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp sidebar_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-100"
    >
      <.icon name={@icon} class="h-5 w-5 text-zinc-400" />
      {@label}
    </a>
    """
  end
end
