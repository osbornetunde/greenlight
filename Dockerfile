# Stage 1: Build the application
FROM golang:1.19-alpine AS builder

# Set working directory
WORKDIR /app

# Copy go.mod and go.sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the application with version information
RUN CGO_ENABLED=0 go build -ldflags='-s -w -X main.version=1.0.0 -X main.buildTime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")' -o=./bin/api ./cmd/api

# Stage 2: Create the final image
FROM alpine:3.16

# Install necessary runtime dependencies
RUN apk --no-cache add ca-certificates tzdata postgresql-client

# Set working directory
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/bin/api /app/bin/api
COPY --from=builder /app/migrations /app/migrations

# Create a non-root user and set permissions
RUN adduser -D -g '' appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose the application port
EXPOSE 4000

# Set environment variables
ENV PORT=4000

# Command to run the application
CMD /app/bin/api -db-dsn=${DATABASE_URL}
