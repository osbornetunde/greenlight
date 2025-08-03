#!/usr/bin/env bash

# Development script for Greenlight API
# This script loads environment variables from .env file and starts the API

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Change to the script's directory
cd "$(dirname "$0")/.."

print_info "Starting Greenlight API in development mode..."

# Check if .env file exists
if [ -f ".env" ]; then
    print_info "Loading environment variables from .env file..."
    # Export variables from .env file
    set -a
    source .env
    set +a
else
    print_warning ".env file not found. Using default configuration."
    print_info "Copy .env.example to .env and customize it for your setup:"
    print_info "  cp .env.example .env"
    echo
fi

# Check if Go is installed
if ! command -v go &> /dev/null; then
    print_error "Go is not installed. Please install Go 1.21+ and try again."
    exit 1
fi

# Check if database connection is set
if [ -z "$GREENLIGHT_DB_DSN" ]; then
    print_error "GREENLIGHT_DB_DSN not set"
    print_info "Database connection is required. Set it in your .env file:"
    print_info "  GREENLIGHT_DB_DSN='postgres://user:pass@localhost/greenlight?sslmode=disable'"
    print_info ""
    print_warning "Starting anyway, but expect the application to fail..."
    sleep 2
else
    print_info "✅ Database DSN configured"
fi

# Check SMTP configuration
print_info "Checking SMTP configuration..."
smtp_config_missing=false

if [ -z "$SMTP_HOST" ]; then
    print_error "SMTP_HOST not set"
    smtp_config_missing=true
fi
if [ -z "$SMTP_PORT" ]; then
    print_error "SMTP_PORT not set"
    smtp_config_missing=true
fi
if [ -z "$SMTP_USERNAME" ]; then
    print_error "SMTP_USERNAME not set"
    smtp_config_missing=true
fi
if [ -z "$SMTP_PASSWORD" ]; then
    print_error "SMTP_PASSWORD not set"
    smtp_config_missing=true
fi
if [ -z "$SMTP_SENDER" ]; then
    print_error "SMTP_SENDER not set"
    smtp_config_missing=true
fi

if [ "$smtp_config_missing" = true ]; then
    print_error "SMTP configuration is incomplete!"
    print_info "User registration emails will not work without proper SMTP settings."
    print_info ""
    print_info "To fix this:"
    print_info "1. Edit your .env file: nano .env"
    print_info "2. Set all SMTP_* variables with your provider credentials"
    print_info "3. For development, sign up at https://mailtrap.io"
    print_info ""
    print_warning "Starting anyway, but expect user registration to fail..."
    sleep 2
else
    print_info "✅ SMTP configuration looks complete"
fi

# Set default port if not specified
if [ -z "$PORT" ]; then
    export PORT=4000
fi

print_info "Configuration Summary:"
print_info ""
print_info "🌐 Server:"
print_info "  Port: ${PORT:-4000}"
print_info "  Environment: ${ENV:-development}"
print_info ""
print_info "🗄️  Database:"
print_info "  DSN: ${GREENLIGHT_DB_DSN:-not set}"
print_info ""
print_info "📧 SMTP:"
print_info "  Host: ${SMTP_HOST:-not set}"
print_info "  Port: ${SMTP_PORT:-not set}"
print_info "  Username: ${SMTP_USERNAME:-not set}"
print_info ""
print_info "🔒 Security:"
print_info "  CORS Origins: ${CORS_TRUSTED_ORIGINS:-not set}"
print_info "  Rate Limiting: ${LIMITER_ENABLED:-true}"
print_info ""
print_info "💡 You can override any setting with command-line flags:"
print_info "  Example: make dev -- -port=8080 -smtp-port=587 -env=staging"
echo

# Check if the database is reachable (optional)
if command -v psql &> /dev/null; then
    print_info "Testing database connection..."
    if psql "$GREENLIGHT_DB_DSN" -c "SELECT 1;" &> /dev/null; then
        print_info "Database connection successful."
    else
        print_warning "Could not connect to database. Make sure PostgreSQL is running."
        print_info "  Start PostgreSQL: brew services start postgresql (macOS)"
        print_info "  Create database: createdb greenlight"
        print_info "  Run migrations: make db/migration/up"
        echo
    fi
fi

# Download dependencies if needed
print_info "Checking Go dependencies..."
go mod download

print_info "Starting API server..."
print_info "API will be available at: http://localhost:$PORT"
print_info "Health check: http://localhost:$PORT/v1/healthcheck"
print_info "Press Ctrl+C to stop the server"
echo

# Start the API (environment variables are loaded automatically from .env)
# Pass through any additional command-line arguments
exec go run ./cmd/api "$@"
