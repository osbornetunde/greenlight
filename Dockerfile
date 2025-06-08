# Build stage
FROM golang:1.20 AS builder

WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./
# Copy the source code
COPY . .

# Build the application using the Makefile
RUN make build/api

# Runtime stage
FROM debian:bullseye-slim

WORKDIR /app

# Install ca-certificates for HTTPS
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy the binary from the builder stage
COPY --from=builder /app/bin/linux_amd64/api /app/api

# Set environment variables
ENV GREENLIGHT_DB_DSN="postgres://greenlight:pa55word@db/greenlight?sslmode=disable"

# Expose the application port
EXPOSE 4000

# Run the application
CMD /app/api -db-dsn ${GREENLIGHT_DB_DSN}
