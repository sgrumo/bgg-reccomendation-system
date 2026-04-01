defmodule ReccoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :recco

  @session_options [
    store: :cookie,
    key: "_recco_key",
    signing_salt: "LQVaD7sn",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :recco,
    gzip: not code_reloading?,
    only: ReccoWeb.static_paths(),
    raise_on_missing_only: code_reloading?

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :recco
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Corsica,
    origins: Application.compile_env(:recco, :cors_origins, ["http://localhost:3000"]),
    allow_headers: ["authorization", "content-type"],
    allow_methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_credentials: true

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug ReccoWeb.Router
end
