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

  # Admin (browser + LiveView)
  scope "/admin", ReccoWeb do
    pipe_through :browser

    live_session :admin, on_mount: [ReccoWeb.Live.AuthHook] do
      # Admin LiveViews go here
    end
  end

  # Metrics dashboard (telemetry_ui)
  if Application.compile_env(:recco, :dev_routes) do
    scope "/dev" do
      pipe_through :browser
    end
  end
end
