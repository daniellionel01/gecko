ARG ERLANG_VERSION=28.0.2.0
ARG GLEAM_VERSION=v1.13.0

# Gleam stage
FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-scratch AS gleam

# Build stage
FROM erlang:${ERLANG_VERSION}-alpine AS build
ARG BUILD_BASE_VER
RUN apk add --no-cache build-base=0.5-r3
WORKDIR /app
COPY --from=gleam /bin/gleam /bin/gleam
COPY . .
RUN gleam export erlang-shipment

# Runtime stage
FROM erlang:${ERLANG_VERSION}-alpine
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG GIT_SHA
ARG BUILD_TIME

ENV GIT_SHA=${GIT_SHA}
ENV BUILD_TIME=${BUILD_TIME}
COPY --from=build /app/priv/db /app/db
COPY --from=build /app/build/erlang-shipment /app
COPY --from=build /app/bin/pod-entrypoint.sh /app
COPY --from=build /app/bin/healthcheck.sh /app
RUN chmod +x /app/*.sh
RUN apk add --no-cache \
  ca-certificates=20250619-r0 \
  curl=8.14.1-r2 \
  sqlite=3.49.2-r1 && \
  apk add --no-cache \
  --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main \
  --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
  ffmpeg=8.0-r3
RUN curl -fsSL https://raw.githubusercontent.com/pressly/goose/master/install.sh | sh -s v3.26.0
WORKDIR /app
ENTRYPOINT ["/app/pod-entrypoint.sh"]
CMD ["run"]
