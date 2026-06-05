defmodule ReccoWeb.LandingLive do
  use ReccoWeb, :live_view

  alias Recco.BoardGames
  alias Recco.Ratings

  @top_n 6

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    %{games: trending} = BoardGames.list_board_games(%{per_page: @top_n, sort: "rating"})

    rated_count =
      case socket.assigns[:current_user] do
        nil -> 0
        user -> Ratings.count_user_ratings(user.id)
      end

    {:ok,
     assign(socket,
       page_title: gettext("Board Game Recommendations"),
       trending: trending,
       rated_count: rated_count
     )}
  end

  @impl true
  @spec render(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.hero current_user={@current_user} trending={@trending} />
    <.how_it_works />
    <.import_nudge :if={@current_user} rated_count={@rated_count} />
    <.prototypes_spotlight current_user={@current_user} />
    """
  end

  ## ── sections ──────────────────────────────────────────────────────────

  attr :current_user, :any, default: nil
  attr :trending, :list, required: true

  defp hero(assigns) do
    ~H"""
    <section class="grid grid-cols-1 lg:grid-cols-[1.08fr_0.92fr] gap-12 items-center py-10 lg:py-14">
      <div>
        <h1 class="text-[clamp(44px,5.6vw,84px)] mb-5 leading-[1.04]">
          {gettext("Discover your next")}
        </h1>
        <h1 class="text-[clamp(44px,5.6vw,84px)] mb-7 inline-block">
          <span
            class="inline-block bg-accent text-accent-ink border-bw border-line rounded-panel-sm px-4 pt-1 pb-2.5 shadow-panel"
            style="transform: rotate(-1.4deg);"
          >
            {gettext("favourite board game")}
          </span>
        </h1>
        <p class="text-[19px] leading-[1.55] text-ink-soft max-w-[480px] mb-7">
          {gettext(
            "Rate the games you love and let BGRecco match you with your next obsession — by category, mechanics and complexity, not popularity."
          )}
        </p>
        <div class="flex flex-wrap items-center gap-3.5">
          <a href={~p"/games"} class="btn btn-primary btn-lg">
            {gettext("Browse all games")} →
          </a>
          <a :if={!@current_user} href={~p"/register"} class="btn btn-lg">
            {gettext("Create account")}
          </a>
        </div>
      </div>

      <.trending_chart trending={@trending} />
    </section>
    """
  end

  attr :trending, :list, required: true

  defp trending_chart(assigns) do
    ~H"""
    <div class="panel self-stretch px-5 pt-5 pb-3">
      <div class="mb-1.5">
        <span class="label label-ink !font-bold">{gettext("Top rated")}</span>
      </div>

      <%= for {game, i} <- Enum.with_index(@trending) do %>
        <.link
          patch={~p"/games/#{game.id}"}
          class={[
            "chart-row",
            i > 0 && "hairline"
          ]}
        >
          <span class={[
            "chart-rank",
            i == 0 && "!text-accent !text-[20px]"
          ]}>
            {i + 1}
          </span>
          <div class="flex-1 min-w-0">
            <div class="font-bold text-base leading-tight truncate text-ink">
              {game.name}
            </div>
            <div class="label !text-[11px] mt-0.5">
              {trending_meta(game)}
            </div>
          </div>
          <span class="font-mono font-bold text-sm border-2 border-line rounded-panel-sm px-2 py-0.5 bg-card2 text-ink whitespace-nowrap">
            ★ {format_rating(game)}
          </span>
        </.link>
      <% end %>
    </div>
    """
  end

  defp how_it_works(assigns) do
    assigns =
      assign(assigns,
        steps: [
          {gettext("Browse & explore"),
           gettext(
             "Search thousands of games sourced from BoardGameGeek. Filter by category, mechanics and player count to find what catches your eye."
           )},
          {gettext("Rate your games"),
           gettext(
             "Rate the games you've played on a 1–10 scale. The more you rate, the better the engine understands your taste."
           )},
          {gettext("Get recommendations"),
           gettext(
             "We analyse categories, mechanics, complexity and more — then use content similarity to surface games you'll love."
           )}
        ]
      )

    ~H"""
    <section class="py-12 lg:py-14">
      <h2 class="text-[clamp(30px,3.4vw,46px)] mb-7">{gettext("How it works")}</h2>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
        <div :for={{{title, body}, i} <- Enum.with_index(@steps)} class="panel px-6 pt-7 pb-7">
          <div class="bignum text-accent text-[64px] mb-3">
            {String.pad_leading(Integer.to_string(i + 1), 2, "0")}
          </div>
          <h3 class="text-2xl mb-2.5">{title}</h3>
          <p class="text-[15.5px] leading-[1.55] text-ink-soft">{body}</p>
        </div>
      </div>
    </section>
    """
  end

  attr :rated_count, :integer, required: true

  defp import_nudge(assigns) do
    ~H"""
    <section class="pb-12 lg:pb-14">
      <div class="panel panel-lg px-9 py-8 bg-card2 grid grid-cols-1 sm:grid-cols-[auto_1fr_auto] gap-7 items-center">
        <div class="font-mono font-bold text-[46px] leading-none text-accent sm:border-r-bw sm:border-line sm:pr-7">
          {@rated_count}
          <div class="label !text-[10px] mt-1.5">{gettext("games rated")}</div>
        </div>
        <div>
          <h3 class="text-[clamp(22px,2.4vw,30px)] mb-1.5">
            <%= if @rated_count > 0 do %>
              {gettext("Your picks are live — sharpen them")}
            <% else %>
              {gettext("Rate a few games to begin")}
            <% end %>
          </h3>
          <p class="text-base text-ink-soft max-w-[560px] m-0">
            {gettext(
              "Already rate games on BoardGameGeek? Link your account to import your ratings in seconds and get far more accurate recommendations."
            )}
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-3">
          <.link navigate={~p"/games"} class="btn whitespace-nowrap">
            {gettext("Rate more")}
          </.link>
          <.link navigate={~p"/profile"} class="btn btn-primary whitespace-nowrap">
            {gettext("Link BGG account")}
          </.link>
        </div>
      </div>
    </section>
    """
  end

  attr :current_user, :any, default: nil

  defp prototypes_spotlight(assigns) do
    assigns =
      assign(assigns,
        checks: [
          gettext("Title, description, player count & play time"),
          gettext("Pick the categories and mechanics that fit"),
          gettext("Credit your team — designers, artists, playtesters"),
          gettext("Upload images of the prototype build")
        ]
      )

    ~H"""
    <section class="pb-16 lg:pb-20">
      <div
        class="panel panel-lg relative overflow-visible px-10 pt-10 pb-11"
        style="background: color-mix(in srgb, var(--accent2) 16%, var(--card));"
      >
        <div
          class="absolute -top-4 -left-2.5 z-[2] bg-accent2 text-accent-ink border-bw border-line shadow-panel-sm uppercase font-bold text-[14px] tracking-[0.12em] px-4 py-1.5"
          style="font-family: 'Anton', var(--font-head); transform: rotate(-7deg);"
        >
          ★ {gettext("For designers")}
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-10 items-center">
          <div>
            <div class="label label-ink !font-bold mb-3">
              {gettext("Community · Prototypes")}
            </div>
            <h2 class="text-[clamp(30px,3.6vw,50px)] mb-3.5 max-w-[420px]">
              {gettext("Designing your own game?")}
            </h2>
            <p class="text-[16.5px] leading-[1.55] text-ink-soft mb-6 max-w-[440px]">
              {gettext(
                "Show your prototype to the community. Share the rules, the team behind it and photos of the build — fellow players can discover what you're working on and reach out to playtest."
              )}
            </p>
            <div class="flex flex-wrap items-center gap-3.5">
              <.link navigate={~p"/prototypes"} class="btn btn-primary">
                {gettext("Browse prototypes")}
              </.link>
              <%= if @current_user do %>
                <.link navigate={~p"/prototypes/new"} class="btn">
                  {gettext("Submit a prototype")}
                </.link>
              <% else %>
                <.link navigate={~p"/register"} class="btn">
                  {gettext("Sign up to submit")}
                </.link>
              <% end %>
            </div>
          </div>

          <div class="panel px-6 py-6 bg-card grid gap-3.5">
            <div :for={check <- @checks} class="flex items-center gap-3.5">
              <span class="w-[30px] h-[30px] flex-shrink-0 grid place-items-center bg-accent2 text-accent-ink border-2 border-line rounded-[8px] font-extrabold text-base">
                ✓
              </span>
              <span class="text-[15.5px] font-semibold text-ink">{check}</span>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  ## ── helpers ───────────────────────────────────────────────────────────

  defp trending_meta(%{year_published: year, categories: cats}) do
    parts =
      [
        year && Integer.to_string(year),
        first_category(cats)
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, " · ")
  end

  defp first_category([%{"value" => v} | _]) when is_binary(v), do: v
  defp first_category(_), do: nil

  defp format_rating(%{bayes_average_rating: r}) when is_float(r),
    do: :erlang.float_to_binary(r, decimals: 1)

  defp format_rating(%{average_rating: r}) when is_float(r),
    do: :erlang.float_to_binary(r, decimals: 1)

  defp format_rating(_), do: "—"
end
