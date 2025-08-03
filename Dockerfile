# syntax=docker/dockerfile:1.6

# -----------------------------------------
# Builder stage: build the Go binary
# -----------------------------------------
FROM golang:1.23.5-alpine AS builder

WORKDIR /src

# Install build tools
RUN apk add --no-cache build-base git

# Enable Go module proxy (optional; relies on default Golang settings)
ENV CGO_ENABLED=0 \
    GO111MODULE=on \
    GOTOOLCHAIN=auto

# Cache dependencies first
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy app source
COPY . .

# Build flags: embed version/time if provided
ARG BUILD_TIME
ARG VERSION
ENV BUILD_TIME=${BUILD_TIME}
ENV VERSION=${VERSION}
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -ldflags="-s -w -X main.buildTime=${BUILD_TIME} -X main.version=${VERSION}" -o /out/api ./cmd/api

# -----------------------------------------
# Runtime stage: minimal image + migrate CLI
# -----------------------------------------
FROM alpine:3.19 AS runtime

WORKDIR /app

# Install runtime dependencies: CA certs, tzdata, curl and migrate CLI
# - curl and ca-certificates are handy for health checks and TLS
# - tzdata for correct time zone handling if needed
# - postgresql14-client provides pg_isready if you want to script readiness checks
RUN apk add --no-cache ca-certificates tzdata curl postgresql15-client

# Install migrate CLI
# Pinned version of golang-migrate/migrate. Update as needed.
ENV MIGRATE_VERSION=v4.16.2
RUN ARCH="$(apk --print-arch)"; \
    case "$ARCH" in \
      x86_64)  MIGRATE_ARCH=linux-amd64  ;; \
      aarch64) MIGRATE_ARCH=linux-arm64  ;; \
      armv7)   MIGRATE_ARCH=linux-armv7  ;; \
      *)       echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/golang-migrate/migrate/releases/download/${MIGRATE_VERSION}/migrate.${MIGRATE_ARCH}.tar.gz" -o /tmp/migrate.tgz && \
    tar -xzf /tmp/migrate.tgz -C /usr/local/bin migrate && \
    rm -f /tmp/migrate.tgz && \
    chmod +x /usr/local/bin/migrate && \
    migrate -version

# Copy binary, migrations, and scripts before creating user
COPY --from=builder /out/api /app/api
# Copy only the migrations directory if it exists
# If it doesn't exist in your repo, this will be empty and harmless.
COPY migrations /app/migrations
COPY scripts/migrate.sh /app/scripts/migrate.sh
RUN chmod +x /app/scripts/migrate.sh

# Create non-root user and fix ownership
RUN addgroup -S app && adduser -S -G app app
RUN chown -R app:app /app
USER app

# Default environment variables (can be overridden at runtime)
ENV PORT=4000
# Example: DATABASE_URL=postgres://user:pass@db:5432/greenlight?sslmode=disable

EXPOSE 4000

# Optionally, you can wrap startup with migrations:
# Set RUN_MIGRATIONS=true to run migrations before starting the API
ENV RUN_MIGRATIONS=true

# Simple entrypoint script inline
# - Runs migrate up if RUN_MIGRATIONS=true and DATABASE_URL present
# - Starts the API
ENTRYPOINT ["/bin/sh", "-c", "if [ \"$RUN_MIGRATIONS\" = \"true\" ]; then if [ -z \"$DATABASE_URL\" ]; then echo 'RUN_MIGRATIONS=true but DATABASE_URL is not set' >&2; exit 1; fi; /app/scripts/migrate.sh up; fi; echo 'Starting Greenlight API on :$PORT...'; exec /app/api -db-dsn \"$GREENLIGHT_DB_DSN\""]
