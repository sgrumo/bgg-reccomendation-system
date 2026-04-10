defmodule ReccoWeb.Router do
  use ReccoWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ReccoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ReccoWeb.Plugs.FetchCurrentUser
  end

  pipeline :authenticated do
    plug ReccoWeb.Plugs.Auth
  end

  # Health & Metrics
  forward("/health", ReccoWeb.Health.Router)

  # Public API
  scope "/api", ReccoWeb do
    pipe_through :api
  end

  # Authenticated API
  scope "/api", ReccoWeb do
    pipe_through [:api, :authenticated]
  end

  # Auth routes (login/register)
  scope "/", ReccoWeb do
    pipe_through :browser

    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    delete "/logout", UserSessionController, :delete
    get "/register", UserRegistrationController, :new
    post "/register", UserRegistrationController, :create
  end

  # Public LiveView pages (browsing, landing)
  scope "/", ReccoWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [{ReccoWeb.Live.UserAuth, :mount_current_user}],
      layout: {ReccoWeb.Layouts, :app} do
      live "/", LandingLive
      live "/games", GameLive.Index
      live "/games/:id", GameLive.Show
    end
  end

  # Authenticated LiveView pages (ratings, preferences)
  scope "/", ReccoWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: [{ReccoWeb.Live.UserAuth, :ensure_authenticated}],
      layout: {ReccoWeb.Layouts, :app} do
      live "/ratings", RatingLive.Index
      live "/preferences", PreferenceLive.Edit
    end
  end

  # Admin (browser + LiveView)
  scope "/admin", ReccoWeb do
    pipe_through :browser

    live_session :admin,
      on_mount: [{ReccoWeb.Live.UserAuth, :ensure_superadmin}],
      layout: {ReccoWeb.Layouts, :admin} do
      # Admin LiveViews go here
    end
  end

  # Dev routes (metrics dashboard, crawler)
  if Application.compile_env(:recco, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      get "/metrics", TelemetryUI.Web, [], assigns: %{telemetry_ui_allowed: true}
      live "/crawler", ReccoWeb.CrawlerLive
    end
  end
end
