defmodule ReccoWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.TelemetryUI.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec metrics() :: [Telemetry.TelemetryUI.Metrics.t()]
  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("recco.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("recco.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("recco.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Crawler
      summary("recco.crawler.batch.stop.duration",
        tags: [:status],
        unit: {:native, :millisecond}
      ),
      counter("recco.crawler.batch.stop.duration",
        tags: [:status],
        unit: {:native, :millisecond}
      ),
      counter("recco.crawler.batch.exception.duration",
        unit: {:native, :millisecond}
      ),

      # BGG API
      summary("recco.bgg.request.stop.duration",
        tags: [:endpoint, :status],
        unit: {:native, :millisecond}
      ),
      counter("recco.bgg.request.stop.duration",
        tags: [:endpoint, :status],
        unit: {:native, :millisecond}
      ),

      # Auth
      summary("recco.auth.login.stop.duration",
        tags: [:result],
        unit: {:native, :millisecond}
      ),
      counter("recco.auth.login.stop.duration",
        tags: [:result],
        unit: {:native, :millisecond}
      ),
      summary("recco.auth.bcrypt.stop.duration",
        tags: [:path],
        unit: {:native, :millisecond}
      ),
      summary("recco.auth.register.stop.duration",
        tags: [:result],
        unit: {:native, :millisecond}
      ),
      counter("recco.auth.token.stop.duration",
        tags: [:result],
        unit: {:native, :millisecond}
      ),

      # Oban
      summary("oban.job.stop.duration",
        tags: [:worker, :state],
        unit: {:native, :millisecond}
      ),
      counter("oban.job.exception.duration",
        tags: [:worker],
        unit: {:native, :millisecond}
      )
    ]
  end

  @spec ui_metrics() :: [struct()]
  def ui_metrics do
    [
      TelemetryUI.Metrics.title("Phoenix"),
      TelemetryUI.Metrics.average_over_time("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        description: "Endpoint response time"
      ),
      TelemetryUI.Metrics.average_over_time("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond},
        description: "Router dispatch time"
      ),
      TelemetryUI.Metrics.count_over_time("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond},
        description: "Request count"
      ),
      TelemetryUI.Metrics.title("Database"),
      TelemetryUI.Metrics.average_over_time("recco.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "Query total time"
      ),
      TelemetryUI.Metrics.average_over_time("recco.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "Query execution time"
      ),
      TelemetryUI.Metrics.title("VM"),
      TelemetryUI.Metrics.last_value("vm.memory.total",
        unit: {:byte, :kilobyte},
        description: "Total memory"
      ),
      TelemetryUI.Metrics.last_value("vm.total_run_queue_lengths.total",
        description: "Run queue length"
      ),
      TelemetryUI.Metrics.title("Crawler"),
      TelemetryUI.Metrics.count_over_time("recco.crawler.batch.stop.duration",
        tags: [:status],
        description: "Crawler batches by outcome"
      ),
      TelemetryUI.Metrics.average_over_time("recco.crawler.batch.stop.duration",
        unit: {:native, :millisecond},
        description: "Crawler batch duration"
      ),
      TelemetryUI.Metrics.title("BGG API"),
      TelemetryUI.Metrics.count_over_time("recco.bgg.request.stop.duration",
        tags: [:status],
        description: "BGG requests by status"
      ),
      TelemetryUI.Metrics.average_over_time("recco.bgg.request.stop.duration",
        tags: [:endpoint],
        unit: {:native, :millisecond},
        description: "BGG request duration by endpoint"
      ),
      TelemetryUI.Metrics.title("Auth"),
      TelemetryUI.Metrics.count_over_time("recco.auth.login.stop.duration",
        tags: [:result],
        description: "Login attempts by result"
      ),
      TelemetryUI.Metrics.average_over_time("recco.auth.bcrypt.stop.duration",
        unit: {:native, :millisecond},
        description: "Bcrypt duration (watch for drift)"
      ),
      TelemetryUI.Metrics.title("Oban"),
      TelemetryUI.Metrics.count_over_time("oban.job.exception.duration",
        tags: [:worker],
        description: "Oban job exceptions"
      ),
      TelemetryUI.Metrics.average_over_time("oban.job.stop.duration",
        tags: [:worker],
        unit: {:native, :millisecond},
        description: "Oban job duration"
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {ReccoWeb, :count_users, []}
    ]
  end
end
