defmodule ReccoWeb.Navigation do
  @moduledoc """
  Navigation components: navbar, mobile menu, sidebar, user menu.

  Visual system: neobrutalist Sticker Shop — accent square wordmark,
  segmented EN/IT toggle, sun/moon theme toggle, accent2 avatar pill.
  Tokens come from `assets/css/app.css`.
  """

  use ReccoWeb, :html

  attr :current_user, :any, default: nil
  attr :current_path, :string, default: nil

  @spec navbar(map()) :: Phoenix.LiveView.Rendered.t()
  def navbar(assigns) do
    assigns = assign(assigns, :nav_items, visible_nav_items(assigns.current_user))

    ~H"""
    <header class="sticky top-0 z-40 bg-card border-b-bw border-line">
      <nav
        class="mx-auto max-w-[1240px] px-7 flex h-[70px] items-center justify-between gap-5"
        aria-label={gettext("Main navigation")}
      >
        <div class="flex items-center gap-8">
          <button
            id="mobile-menu-button"
            phx-hook="MobileMenu"
            class="md:hidden btn btn-sm !p-2"
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
              class="h-5 w-5"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
              />
            </svg>
          </button>

          <a href={~p"/"} class="flex items-center gap-2.5">
            <.wordmark />
          </a>

          <nav class="hidden md:flex items-center gap-1.5" aria-label={gettext("Primary")}>
            <.nav_link
              :for={{label, href} <- @nav_items}
              href={href}
              label={label}
              active={active?(@current_path, href)}
            />
          </nav>
        </div>

        <div class="hidden md:flex items-center gap-2.5">
          <.locale_switcher />
          <.theme_toggle />
          <.user_menu current_user={@current_user} />
        </div>
      </nav>

      <.mobile_menu current_user={@current_user} current_path={@current_path} />
    </header>
    """
  end

  @spec wordmark(map()) :: Phoenix.LiveView.Rendered.t()
  def wordmark(assigns) do
    ~H"""
    <span class="flex items-center gap-2.5">
      <span
        class="w-[30px] h-[30px] grid place-items-center bg-accent text-accent-ink border-bw border-line rounded-[9px] shadow-panel-sm"
        aria-hidden="true"
      >
        <span class="leading-none text-[20px]" style="font-family: 'Anton', var(--font-head);">
          B
        </span>
      </span>
      <span class="font-head font-display text-2xl tracking-head leading-none text-ink">
        BGRecco
      </span>
    </span>
    """
  end

  attr :id, :string, default: "theme-toggle"

  @spec theme_toggle(map()) :: Phoenix.LiveView.Rendered.t()
  def theme_toggle(assigns) do
    ~H"""
    <button
      id={@id}
      phx-hook="ThemeToggle"
      type="button"
      class="btn btn-sm !p-[9px_11px]"
      aria-label={gettext("Toggle dark mode")}
      title={gettext("Toggle dark mode")}
    >
      <%!-- moon shown in light mode (click → switch to dark) --%>
      <svg
        class="block dark:hidden"
        width="16"
        height="16"
        viewBox="0 0 24 24"
        aria-hidden="true"
      >
        <path d="M20 14.5A8 8 0 1 1 9.5 4 6.3 6.3 0 0 0 20 14.5Z" fill="currentColor" />
      </svg>
      <%!-- sun shown in dark mode (click → switch to light) --%>
      <svg
        class="hidden dark:block"
        width="17"
        height="17"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2.2"
        stroke-linecap="round"
        aria-hidden="true"
      >
        <circle cx="12" cy="12" r="4.2" fill="currentColor" stroke="none" />
        <line x1="12" y1="2.5" x2="12" y2="5" />
        <line x1="12" y1="19" x2="12" y2="21.5" />
        <line x1="2.5" y1="12" x2="5" y2="12" />
        <line x1="19" y1="12" x2="21.5" y2="12" />
        <line x1="5.2" y1="5.2" x2="7" y2="7" />
        <line x1="17" y1="17" x2="18.8" y2="18.8" />
        <line x1="5.2" y1="18.8" x2="7" y2="17" />
        <line x1="17" y1="7" x2="18.8" y2="5.2" />
      </svg>
    </button>
    """
  end

  attr :current_user, :any, default: nil
  attr :current_path, :string, default: nil

  @spec mobile_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def mobile_menu(assigns) do
    assigns = assign(assigns, :nav_items, visible_nav_items(assigns.current_user))

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
        class="fixed inset-y-0 left-0 w-full max-w-xs border-r-bw border-line bg-card p-6 overflow-y-auto transition-transform duration-300 -translate-x-full"
      >
        <div class="flex items-center justify-between mb-8">
          <.wordmark />
          <button
            id="mobile-menu-close"
            class="btn btn-sm !p-2"
            aria-label={gettext("Close menu")}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              class="h-5 w-5"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <nav class="space-y-2" aria-label={gettext("Mobile navigation")}>
          <.mobile_link
            :for={{label, href} <- @nav_items}
            href={href}
            label={label}
            active={active?(@current_path, href)}
          />

          <%= if @current_user do %>
            <div class="border-t-bw border-line pt-4 mt-4">
              <.mobile_link
                href={~p"/profile"}
                label={"#{@current_user.username} — #{gettext("Profile")}"}
                active={false}
              />
            </div>
          <% else %>
            <div class="border-t-bw border-line pt-4 mt-4 space-y-2">
              <.mobile_link href={~p"/login"} label={gettext("Sign in")} active={false} />
              <a href={~p"/register"} class="btn btn-primary w-full justify-center">
                {gettext("Create account")}
              </a>
            </div>
          <% end %>

          <div class="border-t-bw border-line pt-4 mt-4 flex items-center gap-3">
            <.locale_switcher />
            <.theme_toggle id="theme-toggle-mobile" />
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
      class="hidden lg:fixed lg:inset-y-0 lg:flex lg:w-64 lg:flex-col z-40"
      aria-label={gettext("Admin sidebar")}
    >
      <div class="flex flex-col flex-grow bg-card border-r-bw border-line pt-6 pb-4 overflow-y-auto">
        <div class="flex items-center gap-2 px-5 mb-7">
          <a href={~p"/"} class="flex items-center gap-2.5">
            <.wordmark />
          </a>
          <span class="label !text-[10px] !bg-accent2 !text-accent-ink px-2 py-0.5 border-2 border-line rounded-panel-sm">
            Admin
          </span>
        </div>
        <nav class="flex-1 px-3 space-y-1" aria-label={gettext("Admin navigation")}>
          <.sidebar_link href={~p"/admin"} icon="hero-chart-bar" label={gettext("Dashboard")} />
          <.sidebar_link href={~p"/admin/users"} icon="hero-users" label={gettext("Users")} />
          <.sidebar_link
            href={~p"/admin/prototypes"}
            icon="hero-puzzle-piece"
            label={gettext("Prototypes")}
          />
          <.sidebar_link href={~p"/admin/jobs"} icon="hero-queue-list" label={gettext("Jobs")} />
          <.sidebar_link href={~p"/admin/crawler"} icon="hero-arrow-path" label={gettext("Crawler")} />
          <.sidebar_link
            href={~p"/admin/feedback"}
            icon="hero-hand-thumb-up"
            label={gettext("Feedback")}
          />
          <.sidebar_link href={~p"/admin/metrics"} icon="hero-signal" label={gettext("Metrics")} />
          <div class="border-t-bw border-line my-3 mx-1"></div>
          <.sidebar_link href={~p"/"} icon="hero-arrow-left" label={gettext("Back to site")} />
        </nav>
        <div class="border-t-bw border-line px-5 pt-4 mt-2">
          <p class="font-bold text-sm text-ink">{@current_user.username}</p>
          <p class="text-xs text-ink-soft truncate">{@current_user.email}</p>
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
    <div :if={@admins != []} class="panel panel-sm bg-card2 p-3 mb-5">
      <p class="label mb-2">
        {gettext("Admins online")} ({length(@admins)})
      </p>
      <ul class="space-y-1.5">
        <li :for={admin <- @admins} class="flex items-center gap-2 text-xs">
          <span class="inline-block h-2 w-2 rounded-full bg-good" aria-hidden="true"></span>
          <span class="font-bold text-ink">{admin.username}</span>
          <span class="text-ink-soft">on {admin.section}</span>
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
      <a href={~p"/profile"} class="btn btn-sm !gap-2">
        <span
          class="w-[22px] h-[22px] rounded-full bg-accent2 text-accent-ink grid place-items-center text-[11px] font-extrabold border border-line"
          aria-hidden="true"
        >
          {avatar_initial(@current_user)}
        </span>
        <span class="font-bold">{@current_user.username}</span>
      </a>
    <% else %>
      <div class="flex items-center gap-2">
        <a href={~p"/login"} class="btn btn-sm">{gettext("Sign in")}</a>
        <a href={~p"/register"} class="btn btn-sm btn-primary">{gettext("Create account")}</a>
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
    <div class="flex items-center border-2 border-line rounded-panel-sm overflow-hidden">
      <.link
        :for={{code, label} <- @locales}
        href={~p"/locale/#{code}"}
        method="put"
        class={[
          "px-2.5 py-1.5 font-mono font-bold text-[13px] transition-colors",
          code == @current && "bg-accent text-accent-ink",
          code != @current && "bg-card text-ink hover:bg-card2"
        ]}
        aria-label={label}
        aria-current={code == @current && "true"}
      >
        {label}
      </.link>
    </div>
    """
  end

  ## ── private helpers ────────────────────────────────────────────────────

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "px-3 py-2 rounded-panel-sm text-[15px] font-bold border-2 transition-colors",
        @active && "bg-accent text-accent-ink border-line",
        !@active && "bg-transparent text-ink border-transparent hover:bg-card2"
      ]}
      aria-current={@active && "page"}
    >
      {@label}
    </a>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp mobile_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "block rounded-panel-sm border-2 px-3 py-2 text-base font-bold transition-colors",
        @active && "bg-accent text-accent-ink border-line",
        !@active && "bg-card text-ink border-line hover:bg-card2"
      ]}
      aria-current={@active && "page"}
    >
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
      class="flex items-center gap-3 rounded-panel-sm px-3 py-2 text-sm font-bold text-ink hover:bg-card2 transition-colors"
    >
      <.icon name={@icon} class="h-5 w-5 text-ink-soft" />
      {@label}
    </a>
    """
  end

  defp visible_nav_items(current_user) do
    items = [
      {gettext("Browse"), "/games", :always},
      {gettext("My Ratings"), "/ratings", :authenticated},
      {gettext("Wishlist"), "/wishlist", :authenticated},
      {gettext("For You"), "/recommendations", :authenticated},
      {gettext("Prototypes"), "/prototypes", :authenticated}
    ]

    items
    |> Enum.filter(fn
      {_label, _href, :always} -> true
      {_label, _href, :authenticated} -> not is_nil(current_user)
    end)
    |> Enum.map(fn {label, href, _scope} -> {label, href} end)
  end

  defp active?(nil, _href), do: false
  defp active?(current_path, href), do: String.starts_with?(current_path, href)

  defp avatar_initial(%{username: username}) when is_binary(username) and username != "",
    do: username |> String.first() |> String.upcase()

  defp avatar_initial(_), do: "?"
end
