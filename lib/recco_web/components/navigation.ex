defmodule ReccoWeb.Navigation do
  @moduledoc """
  Navigation components: navbar, mobile menu, sidebar, user menu.
  """

  use ReccoWeb, :html

  attr :current_user, :any, default: nil

  @spec navbar(map()) :: Phoenix.LiveView.Rendered.t()
  def navbar(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 bg-white border-b border-zinc-200">
      <nav class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8" aria-label="Main navigation">
        <div class="flex h-16 items-center justify-between">
          <div class="flex items-center gap-8">
            <a href={~p"/"} class="text-xl font-bold text-brand-600">Recco</a>
            <div class="hidden md:flex items-center gap-6">
              <.nav_link href={~p"/games"} label="Browse" />
              <%= if @current_user do %>
                <.nav_link href={~p"/ratings"} label="My Ratings" />
                <.nav_link href={~p"/recommendations"} label="For You" />
              <% end %>
            </div>
          </div>

          <div class="hidden md:flex items-center gap-4">
            <.user_menu current_user={@current_user} />
          </div>

          <button
            id="mobile-menu-button"
            phx-hook="MobileMenu"
            class="md:hidden p-2 text-zinc-600 hover:text-zinc-900"
            aria-expanded="false"
            aria-controls="mobile-menu"
            aria-label="Open menu"
          >
            <.icon name="hero-bars-3" class="h-6 w-6" />
          </button>
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
      aria-label="Mobile navigation"
    >
      <div id="mobile-menu-backdrop" class="fixed inset-0 bg-black/25"></div>
      <div
        id="mobile-menu-panel"
        class="fixed inset-y-0 right-0 w-full max-w-xs bg-white shadow-xl p-6 overflow-y-auto"
      >
        <div class="flex items-center justify-between mb-8">
          <span class="text-lg font-bold text-brand-600">Recco</span>
          <button
            id="mobile-menu-close"
            class="p-2 text-zinc-600 hover:text-zinc-900"
            aria-label="Close menu"
          >
            <.icon name="hero-x-mark" class="h-6 w-6" />
          </button>
        </div>

        <nav class="space-y-2" aria-label="Mobile navigation">
          <a
            href={~p"/games"}
            class="block rounded-lg px-3 py-2 text-base font-medium text-zinc-900 hover:bg-zinc-50"
          >
            Browse
          </a>

          <%= if @current_user do %>
            <a
              href={~p"/ratings"}
              class="block rounded-lg px-3 py-2 text-base font-medium text-zinc-900 hover:bg-zinc-50"
            >
              My Ratings
            </a>
            <a
              href={~p"/recommendations"}
              class="block rounded-lg px-3 py-2 text-base font-medium text-zinc-900 hover:bg-zinc-50"
            >
              For You
            </a>
            <div class="border-t border-zinc-200 pt-4 mt-4">
              <p class="px-3 text-sm text-zinc-500 mb-2">{@current_user.username}</p>
              <a
                href={~p"/logout"}
                method="delete"
                class="block rounded-lg px-3 py-2 text-base font-medium text-zinc-900 hover:bg-zinc-50"
              >
                Sign out
              </a>
            </div>
          <% else %>
            <div class="border-t border-zinc-200 pt-4 mt-4 space-y-2">
              <a
                href={~p"/login"}
                class="block rounded-lg px-3 py-2 text-base font-medium text-zinc-900 hover:bg-zinc-50"
              >
                Sign in
              </a>
              <a
                href={~p"/register"}
                class="block rounded-lg px-3 py-2 text-base font-medium text-brand-600 hover:bg-brand-50"
              >
                Create account
              </a>
            </div>
          <% end %>
        </nav>
      </div>
    </div>
    """
  end

  attr :current_user, :any, default: nil

  @spec admin_sidebar(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_sidebar(assigns) do
    ~H"""
    <aside class="hidden lg:fixed lg:inset-y-0 lg:flex lg:w-64 lg:flex-col" aria-label="Admin sidebar">
      <div class="flex flex-col flex-grow border-r border-zinc-200 bg-zinc-50 pt-5 pb-4 overflow-y-auto">
        <div class="flex items-center flex-shrink-0 px-4 mb-6">
          <a href={~p"/"} class="text-xl font-bold text-brand-600">Recco</a>
          <span class="ml-2 text-xs font-medium text-zinc-500 bg-zinc-200 rounded px-1.5 py-0.5">
            Admin
          </span>
        </div>
        <nav class="flex-1 px-3 space-y-1" aria-label="Admin navigation">
          <.sidebar_link href={~p"/admin"} icon="hero-chart-bar" label="Dashboard" />
          <.sidebar_link href={~p"/admin/users"} icon="hero-users" label="Users" />
          <.sidebar_link href={~p"/admin/jobs"} icon="hero-queue-list" label="Jobs" />
          <.sidebar_link href={~p"/admin/crawler"} icon="hero-arrow-path" label="Crawler" />
          <.sidebar_link href={~p"/admin/metrics"} icon="hero-signal" label="Metrics" />
          <div class="border-t border-zinc-200 my-3"></div>
          <.sidebar_link href={~p"/"} icon="hero-arrow-left" label="Back to site" />
        </nav>
        <div class="flex-shrink-0 border-t border-zinc-200 p-4">
          <p class="text-sm font-medium text-zinc-700">{@current_user.username}</p>
          <p class="text-xs text-zinc-500">{@current_user.email}</p>
        </div>
      </div>
    </aside>
    """
  end

  attr :current_user, :any, required: true

  @spec user_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def user_menu(assigns) do
    ~H"""
    <%= if @current_user do %>
      <div class="flex items-center gap-4">
        <span class="text-sm text-zinc-600">{@current_user.username}</span>
        <a
          href={~p"/logout"}
          method="delete"
          class="text-sm font-medium text-zinc-600 hover:text-zinc-900"
        >
          Sign out
        </a>
      </div>
    <% else %>
      <div class="flex items-center gap-3">
        <a href={~p"/login"} class="text-sm font-medium text-zinc-600 hover:text-zinc-900">
          Sign in
        </a>
        <a
          href={~p"/register"}
          class="rounded-lg bg-brand-600 px-3.5 py-2 text-sm font-semibold text-white hover:bg-brand-500"
        >
          Create account
        </a>
      </div>
    <% end %>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true

  defp nav_link(assigns) do
    ~H"""
    <a href={@href} class="text-sm font-medium text-zinc-600 hover:text-zinc-900">
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
