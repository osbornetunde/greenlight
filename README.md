# Greenlight API

## Local Development

This section covers running the API locally for development (with or without Docker), database setup, and developer tooling.

### Prerequisites
- Go 1.21+ (or the version declared in go.mod)
- PostgreSQL 14+ (local install or via Docker/Compose)
- Make (optional but recommended)
- curl (optional, for quick API tests)

### Environment variables
Create a `.env` file or export variables in your shell:
- DATABASE_URL: Postgres connection string (e.g. postgres://user:pass@localhost:5432/greenlight?sslmode=disable)
- SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD (if using mailer for activation emails)
- PORT: API port (default 4000)
- CORS_TRUSTED_ORIGINS: space-separated list of trusted origins (optional in dev)

### Running locally with Go
1. Install dependencies:
   go mod download
2. Set required env variables (see above).
3. Run the server:
   go run ./cmd/api
4. Visit:
   http://localhost:4000/v1/healthcheck

### Using Makefile (if available)
Common targets:
- make run: Run the API locally
- make test: Run tests
- make build: Build the binary
- make tidy: Go mod tidy and vendor updates

### Database migrations
If you manage migrations manually, run your migration tool to apply files in migrations/. Ensure your DATABASE_URL points to your development database.


## Docker Deployment

This project includes a Dockerfile for containerized deployment. The Dockerfile:

1. Builds the application in a Go environment
2. Creates a minimal runtime image with only the necessary dependencies
3. Sets up the application to run with proper permissions
4. Configures environment variables for deployment

### Building the Docker Image

```bash
docker build -t greenlight-api .
```

### Running the Docker Container Locally

```bash
docker run -p 4000:4000 -e DATABASE_URL=your_database_connection_string greenlight-api
```

### Deploying with Railway

When deploying to Railway, the platform will automatically:
1. Detect the Dockerfile and build the image
2. Set up the necessary environment variables
3. Deploy the container with the appropriate configuration

Make sure to set the DATABASE_URL environment variable in your Railway project to connect to your PostgreSQL database.

## How to Deploy to Railway.com (Like You're 5 Years Old)

Hello friend! Let's put our Greenlight app on the internet using Railway.com! It's like building a LEGO tower and showing it to everyone!

### Step 1: Get Ready
1. Ask a grown-up to help you make an account on [Railway.com](https://railway.com)
2. Install Railway on your computer:
   ```
   npm install -g @railway/cli
   ```
3. Login to Railway:
   ```
   railway login
   ```

### Step 2: Connect Your Project
1. Go to your Greenlight folder on your computer
2. Tell Railway about your project:
   ```
   railway init
   ```
3. When it asks questions, just pick the options that make sense to you!

### Step 3: Add a Database
1. In the Railway website, click on "New Project"
2. Click "Provision PostgreSQL"
3. This gives your app a special place to store information, like a toy box!

### Step 4: Connect Your App to the Database
1. In the Railway website, go to your project
2. Click on the PostgreSQL database
3. Look for "Connect" and copy the "DATABASE_URL"
4. Go back to your project settings
5. Click on "Variables"
6. Make sure there's a variable called "DATABASE_URL" with the value you copied

### Step 5: Send Your App to Railway
1. Go back to your computer
2. Make sure you're in your Greenlight folder
3. Tell Railway to take your app:
   ```
   railway up
   ```
4. Wait while Railway builds your app (like putting together a puzzle!)

### Step 6: Tell Everyone About Your App
1. In the Railway website, go to your project
2. Click on "Settings" and then "Generate Domain"
3. Railway will give your app a special address on the internet
4. Now you can share this address with your friends!

### Step 7: Check If Your App Is Working
1. Visit your app's address in a web browser
2. Add "/v1/healthcheck" to the end of the address
3. If you see a happy message, your app is working! Hooray!

That's it! You've put your app on the internet, just like a real programmer! 🎉

## API Documentation

### Base URL
```
http://localhost:4000/v1
```

### Authentication
Most endpoints require authentication using Bearer tokens. Include the token in the Authorization header:
```
Authorization: Bearer <your_token_here>
```

### Permission System
The API uses a permission-based system with two main permissions:
- `movies:read` - Required to view movies
- `movies:write` - Required to create, update, or delete movies

New users automatically receive `movies:read` permission upon registration.

### Content Type
All requests and responses use `application/json` content type.

---

## Endpoints

### Health Check

#### GET /v1/healthcheck
Check if the API is running and get system information.

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

2. **Activate account** (use token from email):
```bash
curl -X PUT http://localhost:4000/v1/users/activated \
  -H "Content-Type: application/json" \
  -d '{
    "token": "ACTIVATION_TOKEN_FROM_EMAIL"
  }'
```

3. **Get authentication token:**
```bash
curl -X POST http://localhost:4000/v1/tokens/authentication \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "securepassword123"
  }'
```

4. **Use token to access protected endpoints:**
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
