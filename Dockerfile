ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.2
ARG DEBIAN_CODENAME=bookworm

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_CODENAME}-20250407"
ARG RUNNER_IMAGE="debian:${DEBIAN_CODENAME}-slim"

# --- Build stage ---
FROM ${BUILDER_IMAGE} AS builder

ENV MIX_ENV=prod

RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

# Install deps first (cache layer)
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

# Build assets
COPY priv priv
COPY assets assets
RUN mix assets.deploy

# Compile application
COPY lib lib
RUN mix compile

# Copy runtime config last
COPY config/runtime.exs config/

# Build release
RUN mix release

# --- Runtime stage ---
FROM ${RUNNER_IMAGE}

ENV MIX_ENV=prod
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app
RUN useradd --system --create-home app && chown -R app:app /app
USER app

COPY --from=builder --chown=app:app /app/_build/prod/rel/recco ./

CMD ["bin/recco", "start"]
