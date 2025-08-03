# Greenlight API

A modern RESTful API for managing movies with user authentication, permissions, and rate limiting. Built with Go, PostgreSQL, and Docker.

## Quick Start

### With Docker (Recommended)

1. **Clone and setup:**
   ```bash
   git clone <repository-url>
   cd greenlight
   ```

2. **Configure SMTP (Required):**
   ```bash
   # Copy environment template
   make env/copy
   
   # Edit .env file with your SMTP credentials
   nano .env
   # Set SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD
   ```

3. **Start the application:**
   ```bash
   make compose/up
   ```

4. **Verify it's running:**
   ```bash
   make compose/health
   ```

### Without Docker

1. **Prerequisites:**
   - Go 1.21+ 
   - PostgreSQL 14+
   - migrate CLI tool

2. **Setup environment (Required):**
   ```bash
   # Copy example environment file
   make env/copy
   
   # Edit .env file with your SMTP credentials
   nano .env
   # You MUST set SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD
   
   # Check configuration
   make env/check
   ```

3. **Setup database:**
   ```bash
   # Create database
   createdb greenlight
   
   # Run migrations
   make db/migration/up
   ```

4. **Run the application:**
   ```bash
   # Using environment variables (recommended)
   make dev
   ```

## Local Development Setup

### Environment Setup (Required)

**⚠️ SMTP configuration is REQUIRED** - the application will not start without proper SMTP settings for user registration emails.

The application uses a flexible configuration system that loads settings from:
1. **`.env` file** (automatically loaded on startup)
2. **`.env.local` file** (optional local overrides, git-ignored)
3. **Environment variables** (override file values)
4. **Command-line flags** (override everything - highest priority)

**Development Enhancement:** If you have `direnv` installed, the `.envrc` file will automatically load both `.env` and `.env.local` files when you enter the project directory, plus add helpful aliases and development tools.

#### Quick Setup

```bash
# 1. Copy the example environment file
make env/copy

# 2. Edit the .env file with your SMTP credentials
nano .env
# Set SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD, SMTP_SENDER

# 3. (Optional) Create local overrides for personal settings
cp .env.local.example .env.local
nano .env.local

# 4. Check your configuration
make env/check

# 5. Get SMTP help if needed
make env/smtp

# 6. Start the application
make dev
```

#### Manual Environment Setup

Create a `.env` file in the project root with **REQUIRED** configuration:

```bash
# Server Configuration
PORT=4000
ENV=development

# Database (REQUIRED - app won't start without this)
GREENLIGHT_DB_DSN=postgres://username:password@localhost/greenlight?sslmode=disable

# SMTP Configuration (REQUIRED - app won't start without these)
SMTP_HOST=sandbox.smtp.mailtrap.io
SMTP_PORT=2525
SMTP_USERNAME=your_actual_mailtrap_username
SMTP_PASSWORD=your_actual_mailtrap_password
SMTP_SENDER=Greenlight <no-reply@greenlight.com>

# CORS and Security
CORS_TRUSTED_ORIGINS=http://localhost:3000 http://localhost:5173
LIMITER_ENABLED=true
```

**🚨 Important:** Replace `your_actual_*` values with real credentials from your SMTP provider.

#### Configuration Loading & Priority

The application automatically loads your `.env` file on startup and reads configuration in this order (highest to lowest priority):

1. **Command-line flags** (e.g., `-port=8080`, `-env=staging`, `-smtp-port=587`) - highest priority
2. **Environment variables** (e.g., `export PORT=8080`, `export ENV=staging`) - overrides files
3. **`.env.local` file values** (optional, git-ignored) - personal overrides
4. **`.env` file values** - automatically loaded defaults
5. **Error if not provided** - no hardcoded defaults (for required settings)

This means you can:
- Set team defaults in `.env` file (committed to git)
- Set personal preferences in `.env.local` file (git-ignored)
- Override with environment variables for different environments  
- Use command-line flags for temporary testing or overrides

**All configuration (server, database, SMTP, CORS, rate limiting) uses this same system.**

### Development Environment Enhancement (Optional)

If you have `direnv` installed (https://direnv.net/), you get additional benefits:
- Automatic loading of `.env` and `.env.local` files when entering the project directory
- Helpful aliases: `dev`, `check`, `smtp-help`, `test_config`, `health`
- Project tools added to PATH
- Configuration summary displayed when entering directory

Install direnv:
```bash
# macOS
brew install direnv

# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
eval "$(direnv hook bash)"  # or zsh, fish, etc.

# Allow the .envrc file
cd greenlight
direnv allow
```

### SMTP Configuration (Required!)

**⚠️ SMTP configuration is MANDATORY** - the application will not start without proper SMTP settings. User registration requires sending activation emails.

#### Option 1: Mailtrap (Recommended for Development)
1. Sign up at [Mailtrap.io](https://mailtrap.io)
2. Create an inbox
3. Add to your `.env` file:
   ```bash
   SMTP_HOST=sandbox.smtp.mailtrap.io
   SMTP_PORT=2525
   SMTP_USERNAME=your_mailtrap_username
   SMTP_PASSWORD=your_mailtrap_password
   ```

#### Option 2: Gmail SMTP
Add to your `.env` file:
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-16-character-app-password
```

#### Option 3: SendGrid
Add to your `.env` file:
```bash
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your-sendgrid-api-key
```

**⚠️ Important:** Port 25 is commonly blocked by ISPs and cloud providers. Always use alternative ports like 2525 or 587.

#### Configuration Override Examples

You can override `.env` settings with environment variables or command-line flags:

```bash
# Server configuration overrides
PORT=8080 ENV=staging make dev
go run ./cmd/api -port=9090 -env=production

# Database overrides
GREENLIGHT_DB_DSN="postgres://user:pass@other-host/db" make dev
go run ./cmd/api -db-dsn="postgres://user:pass@localhost/testdb"

# SMTP overrides  
make dev -smtp-port=587
go run ./cmd/api -smtp-host=smtp.gmail.com -smtp-port=587

# CORS and rate limiting overrides
CORS_TRUSTED_ORIGINS="https://app.example.com" LIMITER_ENABLED=false make dev
go run ./cmd/api -cors-trusted-origins="https://prod.example.com" -limiter-enabled=false

# Override multiple settings for testing
go run ./cmd/api \
  -port=8080 \
  -env=staging \
  -db-dsn="postgres://test:pass@localhost/testdb" \
  -smtp-host=smtp.gmail.com \
  -smtp-port=587 \
  -cors-trusted-origins="https://test.example.com"
```

### Running Locally (Without Docker)

#### Prerequisites
- Go 1.21+ (check with `go version`)
- PostgreSQL 14+ (local installation)
- [golang-migrate](https://github.com/golang-migrate/migrate) CLI tool
- Make (optional but recommended)

#### Step-by-step Setup

1. **Install dependencies:**
   ```bash
   go mod download
   ```

2. **Setup PostgreSQL database:**
   ```bash
   # Create database
   createdb greenlight
   
   # Or using psql
   psql postgres -c "CREATE DATABASE greenlight;"
   ```

3. **Run database migrations:**
   ```bash
   # Set your database connection string
   export GREENLIGHT_DB_DSN="postgres://username:password@localhost/greenlight?sslmode=disable"
   
   # Apply migrations
   make db/migration/up
   ```

4. **Run the application:**
   ```bash
   # Option 1: Using .env file (recommended)
   make dev
   
   # Option 2: Using .env file with overrides
   make dev -smtp-port=587 -smtp-host=smtp.gmail.com
   
   # Option 3: Using environment variables
   SMTP_PORT=587 make dev
   
   # Option 4: Direct go run (loads .env automatically)
   go run ./cmd/api
   
   # Option 5: Direct go run with command-line overrides
   go run ./cmd/api -smtp-port=587 -smtp-host=smtp.gmail.com
   ```

5. **Verify it's working:**
   ```bash
   curl http://localhost:4000/v1/healthcheck
   ```

#### Available Make Commands

```bash
# Development
make dev                    # Run API with .env file configuration
make run/api                # Run API with .envrc configuration
make env/copy               # Copy .env.example to .env
make env/check              # Check environment configuration
make env/smtp               # Show SMTP setup help

# Database
make db/psql                # Connect to database
make db/migration/new name=migration_name  # Create new migration
make db/migration/up         # Apply all migrations
make db/migration/down       # Rollback all migrations

# Quality Control
make audit                  # Format, vet, and test code
make vendor                 # Tidy and vendor dependencies

# Build
make build/api              # Build binary
```

## Docker Development

### Using Docker Compose (Recommended)

The project includes a complete Docker Compose setup with PostgreSQL, automatic migrations, and the API.

#### Quick Start Commands

```bash
# Start everything (builds API, starts DB, runs migrations)
make compose/up

# Check if API is healthy
make compose/health

# View logs
make compose/logs

# Stop services (keeps data)
make compose/down

# Stop and remove all data
make compose/down/v
```

#### Docker Compose Services

The `docker-compose.yml` includes:

1. **PostgreSQL Database** (`db`)
   - Postgres 15 with health checks
   - Persistent data storage
   - Accessible on `localhost:5432`

2. **Database Migrations** (`migrations`)
   - Runs once to set up the database schema
   - Waits for DB to be healthy
   - Uses the same API image

3. **API Server** (`api`)
   - Builds from local Dockerfile
   - Waits for migrations to complete
   - Accessible on `localhost:4000`

#### Customizing Docker Setup

**⚠️ You MUST configure SMTP before using Docker:**

**Option 1: Use .env file (Recommended)**
```bash
# 1. Copy environment template
make env/copy

# 2. Edit .env with your SMTP credentials
nano .env

# 3. Start Docker (will read from .env automatically)
make compose/up
```

**Option 2: Edit docker-compose.yml directly**
```yaml
api:
  environment:
    # Replace with your actual SMTP credentials
    SMTP_HOST: "sandbox.smtp.mailtrap.io"
    SMTP_PORT: "2525"
    SMTP_USERNAME: "your_actual_username"
    SMTP_PASSWORD: "your_actual_password"
    SMTP_SENDER: "Greenlight <no-reply@greenlight.com>"
```

**🚨 Important:** The default values in `docker-compose.yml` are placeholders. You must replace them with real credentials.

#### Docker Compose Commands

```bash
# Build and start services
make compose/up

# Restart just the API
make compose/restart

# Connect to database
make compose/psql

# Run migrations manually
make compose/migrate/up

# View migration status
make compose/migrate/version

# Build just the API image
make compose/build
```

### Single Container Deployment

For production deployment with an external database:

```bash
# Build the image
docker build -t greenlight-api .

# Run with environment variables
docker run -p 4000:4000 \
  -e GREENLIGHT_DB_DSN="postgres://user:pass@host:5432/db?sslmode=disable" \
  -e SMTP_HOST="smtp.sendgrid.net" \
  -e SMTP_PORT="587" \
  -e SMTP_USERNAME="apikey" \
  -e SMTP_PASSWORD="your-api-key" \
  greenlight-api
```

## Command Line Flags

The API accepts various configuration flags:

```bash
./api -help

Flags:
  -port int                    API server port (overrides PORT env var, default 4000)
  -env string                  Environment (overrides ENV env var, default "development")
  -db-dsn string              PostgreSQL DSN (overrides GREENLIGHT_DB_DSN env var)
  -db-max-open-conns int      PostgreSQL max open connections (default 25)
  -db-max-idle-conns int      PostgreSQL max idle connections (default 25)
  -db-max-idle-time string    PostgreSQL max connection idle time (default "15m")
  -limiter-rps float          Rate limiter maximum requests per second (default 2)
  -limiter-burst int          Rate limiter maximum burst (default 4)
  -limiter-enabled            Enable rate limiter (overrides LIMITER_ENABLED env var, default true)
  -smtp-host string           SMTP host (overrides SMTP_HOST env var)
  -smtp-port int              SMTP port (overrides SMTP_PORT env var)
  -smtp-username string       SMTP username (overrides SMTP_USERNAME env var)
  -smtp-password string       SMTP password (overrides SMTP_PASSWORD env var)
  -smtp-sender string         SMTP sender (overrides SMTP_SENDER env var)
  -cors-trusted-origins       Trusted CORS origins (overrides CORS_TRUSTED_ORIGINS env var)
  -version                    Display version and exit
```

**Note:** Database and SMTP settings are required and must be set via `.env` file, environment variables, or command-line flags. Server settings (PORT, ENV), CORS, and rate limiting have sensible defaults but can be customized. The application automatically loads `.env` file on startup.

## API Documentation

### Base URL
```
http://localhost:4000/v1
```

### Authentication
Most endpoints require authentication using Bearer tokens:
```
Authorization: Bearer <your_token_here>
```

### Permission System
- `movies:read` - View movies (auto-granted to new users)
- `movies:write` - Create, update, delete movies

### Content Type
All requests and responses use `application/json`.

---

## Endpoints

### Health Check

#### GET /v1/healthcheck
Check API status and system information.

**Authentication:** None required

**Response:**
```json
{
    "status": "available",
    "system_info": {
        "environment": "development",
        "version": "1.0.0"
    }
}
```

---

### Authentication & Users

#### POST /v1/users
Register a new user account.

**Authentication:** None required

**Request Body:**
```json
{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "securepassword123"
}
```

**Validation Rules:**
- `name`: Required, max 500 characters
- `email`: Required, valid email format
- `password`: Required, 8-72 characters

**Response (202 Accepted):**
```json
{
    "user": {
        "id": 1,
        "created_at": "2023-01-01T12:00:00Z",
        "name": "John Doe",
        "email": "john@example.com",
        "activated": false
    }
}
```

**Note:** An activation email will be sent to the provided email address.

#### PUT /v1/users/activated
Activate a user account using the activation token from email.

**Authentication:** None required

**Request Body:**
```json
{
    "token": "ACTIVATION_TOKEN_FROM_EMAIL"
}
```

**Response (200 OK):**
```json
{
    "user": {
        "id": 1,
        "created_at": "2023-01-01T12:00:00Z",
        "name": "John Doe",
        "email": "john@example.com",
        "activated": true
    }
}
```

#### POST /v1/tokens/authentication
Create an authentication token for login.

**Authentication:** None required

**Request Body:**
```json
{
    "email": "john@example.com",
    "password": "securepassword123"
}
```

**Response (201 Created):**
```json
{
    "authentication_token": {
        "token": "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        "expiry": "2023-01-02T12:00:00Z"
    }
}
```

**Note:** Tokens expire after 24 hours.

---

### Movies

#### GET /v1/movies
Get a paginated list of movies with optional filtering and sorting.

**Authentication:** Required (`movies:read` permission)

**Query Parameters:**
- `title` (optional): Filter by movie title (partial match)
- `genres` (optional): Filter by genres (comma-separated, e.g., "action,comedy")
- `page` (optional): Page number (default: 1, max: 10,000,000)
- `page_size` (optional): Items per page (default: 20, max: 100)
- `sort` (optional): Sort field (default: "id")
  - Available: `id`, `title`, `year`, `runtime`, `-id`, `-title`, `-year`, `-runtime`
  - Prefix with `-` for descending order

**Example Request:**
```
GET /v1/movies?title=batman&genres=action&page=1&page_size=10&sort=-year
```

**Response (200 OK):**
```json
{
    "movies": [
        {
            "id": 1,
            "title": "The Dark Knight",
            "year": 2008,
            "runtime": "152 mins",
            "genres": ["action", "crime", "drama"],
            "version": 1
        }
    ],
    "metadata": {
        "current_page": 1,
        "page_size": 10,
        "first_page": 1,
        "last_page": 5,
        "total_records": 42
    }
}
```

#### GET /v1/movies/:id
Get a specific movie by ID.

**Authentication:** Required (`movies:read` permission)

**Response (200 OK):**
```json
{
    "movie": {
        "id": 1,
        "title": "The Dark Knight",
        "year": 2008,
        "runtime": "152 mins",
        "genres": ["action", "crime", "drama"],
        "version": 1
    }
}
```

#### POST /v1/movies
Create a new movie.

**Authentication:** Required (`movies:write` permission)

**Request Body:**
```json
{
    "title": "Inception",
    "year": 2010,
    "runtime": "148 mins",
    "genres": ["action", "sci-fi", "thriller"]
}
```

**Validation Rules:**
- `title`: Required, max 500 characters
- `year`: Required, between 1888 and current year
- `runtime`: Required, positive integer (format: "XXX mins")
- `genres`: Required, 1-5 unique genres

**Response (201 Created):**
```json
{
    "movie": {
        "id": 2,
        "title": "Inception",
        "year": 2010,
        "runtime": "148 mins",
        "genres": ["action", "sci-fi", "thriller"],
        "version": 1
    }
}
```

**Headers:**
```
Location: /v1/movies/2
```

#### PATCH /v1/movies/:id
Update an existing movie (partial update).

**Authentication:** Required (`movies:write` permission)

**Request Body (all fields optional):**
```json
{
    "title": "Inception: Director's Cut",
    "year": 2010,
    "runtime": "158 mins",
    "genres": ["action", "sci-fi", "thriller", "drama"]
}
```

**Response (200 OK):**
```json
{
    "movie": {
        "id": 2,
        "title": "Inception: Director's Cut",
        "year": 2010,
        "runtime": "158 mins",
        "genres": ["action", "sci-fi", "thriller", "drama"],
        "version": 2
    }
}
```

**Note:** The `version` field is automatically incremented for optimistic locking.

#### DELETE /v1/movies/:id
Delete a movie.

**Authentication:** Required (`movies:write` permission)

**Response (200 OK):**
```json
{
    "message": "movie successfully deleted"
}
```

---

### Debug Endpoint

#### GET /debug/vars
Get application metrics and runtime information.

**Authentication:** None required

**Response (200 OK):**
```json
{
    "cmdline": ["./api"],
    "memstats": {...},
    "total_requests_received": 1234,
    "total_responses_sent": 1234,
    "total_processing_time_μs": 567890,
    "total_responses_sent_by_status": {
        "200": 1000,
        "404": 50,
        "500": 2
    },
    "version": "1.0.0",
    "goroutines": 10,
    "database": {...},
    "timestamp": 1672531200
}
```

---

## Error Responses

All error responses follow a consistent format:

### Error Response Format
```json
{
    "error": "error message or validation errors object"
}
```

### HTTP Status Codes

| Status Code | Description | Example Scenario |
|-------------|-------------|------------------|
| 400 | Bad Request | Invalid JSON in request body |
| 401 | Unauthorized | Missing or invalid authentication token |
| 403 | Forbidden | User lacks required permissions or account not activated |
| 404 | Not Found | Resource doesn't exist |
| 405 | Method Not Allowed | HTTP method not supported for endpoint |
| 409 | Conflict | Edit conflict (version mismatch) |
| 422 | Unprocessable Entity | Validation errors |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server-side error |

### Validation Error Response (422)
```json
{
    "error": {
        "title": "must be provided",
        "year": "must be greater than 1888",
        "genres": "must contain at least 1 genre"
    }
}
```

### Authentication Error Response (401)
```json
{
    "error": "invalid or missing authentication token"
}
```

### Permission Error Response (403)
```json
{
    "error": "your user account doesn't have the necessary permissions to access this resource"
}
```

### Not Found Error Response (404)
```json
{
    "error": "the requested resource could not be found"
}
```

### Rate Limit Error Response (429)
```json
{
    "error": "rate limit exceeded"
}
```

---

## Rate Limiting

The API implements rate limiting to prevent abuse:
- **Default limit:** 2 requests per second
- **Burst capacity:** 4 requests
- Rate limiting can be disabled in development mode

When rate limit is exceeded, the API returns a 429 status code.

---

## CORS

The API supports Cross-Origin Resource Sharing (CORS). Configure trusted origins using the `cors-trusted-origins` flag when starting the server.

---

## Troubleshooting

### Common Issues

#### 1. Database Configuration Missing
**Problem:** Application won't start with message "Error: Database DSN is required"

**Solution:** Configure database in your .env file:
```bash
# 1. Copy template and edit
make env/copy
nano .env

# 2. Set required database variable
GREENLIGHT_DB_DSN=postgres://username:password@localhost/greenlight?sslmode=disable

# 3. Check your configuration
make env/check
```

#### 2. SMTP Configuration Missing
**Problem:** Application won't start with message "Error: SMTP host is required"

**Solution:** Configure SMTP in your .env file:
```bash
# 1. Copy template and edit
make env/copy
nano .env

# 2. Set required SMTP variables
SMTP_HOST=sandbox.smtp.mailtrap.io
SMTP_PORT=2525
SMTP_USERNAME=your_username
SMTP_PASSWORD=your_password
SMTP_SENDER=Your App <noreply@yourapp.com>

# 3. Get help if needed
make env/smtp
```

#### 3. SMTP Connection Timeout
**Problem:** Getting `dial tcp x.x.x.x:25: i/o timeout` during user registration.

**Solution:** Port 25 is blocked. Use port 2525 instead:
```bash
# Option 1: Set in .env file
SMTP_PORT=2525

# Option 2: Override with command-line flag
go run ./cmd/api -smtp-port=2525

# Option 3: Environment variable override
SMTP_PORT=2525 go run ./cmd/api
```

#### 4. Database Connection Failed
**Problem:** `connection refused` or `database does not exist`.

**Solutions:**
- Ensure PostgreSQL is running: `brew services start postgresql` (macOS) or `sudo service postgresql start` (Linux)
- Create the database: `createdb greenlight`
- Check your DSN format: `postgres://username:password@localhost/greenlight?sslmode=disable`

#### 5. Migration Errors
**Problem:** Migration fails or database schema is outdated.

**Solutions:**
```bash
# Check migration status
make db/migration/version

# Apply migrations
make db/migration/up

# Or reset (⚠️ destroys data)
make db/migration/down
make db/migration/up
```

#### 6. Docker Build Issues
**Problem:** Docker build fails or containers won't start.

**Solutions:**
```bash
# Rebuild everything
make compose/down
make compose/build
make compose/up

# Check logs
make compose/logs

# Reset everything (⚠️ destroys data)
make compose/down/v
make compose/up
```

#### 7. Permission Denied Errors
**Problem:** User can't create/update/delete movies.

**Solution:** Users need `movies:write` permission. This must be granted manually in the database:
```sql
INSERT INTO users_permissions (user_id, permission_id) 
SELECT u.id, p.id FROM users u, permissions p 
WHERE u.email = 'user@example.com' AND p.code = 'movies:write';
```

### Getting Help

If you encounter issues:

1. Check the logs: `make compose/logs` (Docker) or view console output
2. Verify your configuration matches the examples above
3. Ensure all prerequisites are installed and running
4. Check that ports 4000 and 5432 are available

---

## Example Usage

### Complete Authentication Flow

1. **Register a new user:**
```bash
curl -X POST http://localhost:4000/v1/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "securepassword123"
  }'
```

2. **Check your email** (Mailtrap inbox) for activation token

3. **Activate account:**
```bash
curl -X PUT http://localhost:4000/v1/users/activated \
  -H "Content-Type: application/json" \
  -d '{
    "token": "ACTIVATION_TOKEN_FROM_EMAIL"
  }'
```

4. **Get authentication token:**
```bash
curl -X POST http://localhost:4000/v1/tokens/authentication \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "securepassword123"
  }'
```

5. **Use token to access protected endpoints:**
```bash
curl -X GET http://localhost:4000/v1/movies \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### Create a Movie
```bash
curl -X POST http://localhost:4000/v1/movies \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "title": "The Matrix",
    "year": 1999,
    "runtime": "136 mins",
    "genres": ["action", "sci-fi"]
  }'
```

### Search Movies
```bash
curl "http://localhost:4000/v1/movies?title=matrix&genres=sci-fi&sort=-year" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## Project Structure

```
greenlight/
├── cmd/
│   ├── api/              # Main application
│   └── examples/         # Example code
├── internal/
│   ├── data/            # Database models and queries
│   ├── jsonlog/         # Structured logging
│   ├── mailer/          # Email functionality
│   └── validator/       # Input validation
├── migrations/          # Database migrations
├── remote/              # Deployment scripts
├── scripts/            # Utility scripts
├── vendor/             # Vendored dependencies
├── docker-compose.yml  # Docker Compose configuration
├── Dockerfile          # Container build instructions
├── Makefile           # Build and development commands
└── README.md          # This file
```

---

## Development Workflow

### Typical Development Session

**With Docker:**
```bash
# Start the stack
make compose/up

# Make code changes...

# Restart API to pick up changes
make compose/restart

# View logs
make compose/logs

# Run tests
make audit

# When done
make compose/down
```

**Without Docker:**
```bash
# Setup environment (first time only)
make env/copy
# Edit .env file with your configuration (database and SMTP required)

# Optional: Create personal overrides
cp .env.local.example .env.local
# Edit .env.local for personal settings

make env/check  # Verify configuration

# Start development
make dev

# If using direnv, you get helpful aliases:
dev           # Same as make dev
check         # Same as make env/check
test_config   # Test current configuration
health        # Check API health

# Test with different settings
make dev -- -port=8080 -env=staging

# Make code changes...
# The server will need to be restarted manually

# Run tests
make audit
```

### Adding New Features

1. **Database changes:** Create migrations with `make db/migration/new name=feature_name`
2. **Code changes:** Modify files in `internal/` or `cmd/`
3. **Testing:** Run `make audit` to format, vet, and test
4. **Integration testing:** Use `curl` commands or Postman to test endpoints

### Production Deployment

For production deployment, consider:

1. **Environment variables:** Use secure credential management
2. **Database:** Use managed PostgreSQL service
3. **Email service:** Use production SMTP service (SendGrid, Mailgun, etc.)
4. **TLS/SSL:** Terminate TLS at load balancer or reverse proxy
5. **Monitoring:** Add health checks, logging, and metrics collection
6. **Scaling:** Use container orchestration (Kubernetes, Docker Swarm)

This README should provide everything needed to get started with the Greenlight API project!