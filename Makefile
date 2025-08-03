# Include variables from the .env file (optional)
-include .env
COMPOSE ?= docker compose
COMPOSE_FILE ?= docker-compose.yml

# =============================================================================
# HELPERS
# =============================================================================

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} |   column -t -s ':' |  sed -e 's/^/ /'
	@echo ''
	@echo 'Compose targets:'
	@echo '  compose/up               Start API and Postgres in background'
	@echo '  compose/down             Stop and remove compose services'
	@echo '  compose/down/v           Stop and remove services and volumes (DB data)'
	@echo '  compose/build            Build API image via compose'
	@echo '  compose/restart          Restart API container'
	@echo '  compose/logs             Tail logs for API and DB'
	@echo '  compose/psql             Open psql to the compose Postgres'
	@echo '  compose/health           Check API health endpoint'
	@echo '  compose/migrate/up       Run DB migrations inside API container'
	@echo '  compose/migrate/down     Roll back DB migrations inside API container'
	@echo '  compose/migrate/version  Show current migration version'
	@echo '  compose/migrations/up    Run the dedicated migrations service'
	@echo '  compose/migrations/down  Stop and remove the dedicated migrations service'
	@echo '  compose/migrations/rerun Rebuild and rerun the migrations service'
	@echo ''
	@echo 'Environment targets:'
	@echo '  dev                      Start API with .env file configuration'
	@echo '  env/copy                 Copy .env.example to .env'
	@echo '  env/copy/local           Copy .env.local.example to .env.local'
	@echo '  env/check                Check environment configuration'
	@echo '  env/smtp                 Show SMTP configuration help'

.PHONY: confirm
confirm:
	@printf 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]

# =============================================================================
# DEVELOPMENT
# =============================================================================

## run/api: run the cmd/api application
.PHONY: run/api
run/api:
	./bin/run_api.sh -db-dsn=${GREENLIGHT_DB_DSN}

## dev: run the API with environment variables from .env file (supports additional args)
.PHONY: dev
dev:
	./scripts/dev.sh $(filter-out $@,$(MAKECMDGOALS))

# Catch-all target to handle additional arguments passed to make dev
%:
	@:

## env/copy: copy .env.example to .env for customization
.PHONY: env/copy
env/copy:
	@if [ -f .env ]; then \
		echo "⚠️  .env file already exists. Skipping copy."; \
		echo "💡 To reset, remove .env first: rm .env"; \
	else \
		cp .env.example .env; \
		echo "✅ Created .env file from .env.example"; \
		echo "💡 Edit .env file to customize your configuration"; \
	fi

## env/copy/local: copy .env.local.example to .env.local for personal overrides
.PHONY: env/copy/local
env/copy/local:
	@if [ -f .env.local ]; then \
		echo "⚠️  .env.local file already exists. Skipping copy."; \
		echo "💡 To reset, remove .env.local first: rm .env.local"; \
	else \
		cp .env.local.example .env.local; \
		echo "✅ Created .env.local file from .env.local.example"; \
		echo "💡 Edit .env.local file for personal configuration overrides"; \
		echo "💡 .env.local is git-ignored and takes precedence over .env"; \
	fi

## env/check: validate environment configuration
.PHONY: env/check
env/check:
	@echo "Checking environment configuration..."
	@if [ -f .env ]; then \
		echo "✅ .env file found"; \
		if [ -f .env.local ]; then \
			echo "✅ .env.local file found (personal overrides)"; \
		fi; \
		echo ""; \
		echo "🔧 Server Configuration:"; \
		source .env && echo "  Port: $${PORT:-not set (default: 4000)}"; \
		source .env && echo "  Environment: $${ENV:-not set (default: development)}"; \
		echo ""; \
		echo "🔧 Database Configuration:"; \
		source .env && echo "  DSN: $${GREENLIGHT_DB_DSN:-not set}"; \
		source .env && if [ -z "$$GREENLIGHT_DB_DSN" ]; then \
			echo "  ⚠️  Database DSN not set. Application will fail to start."; \
			echo "  💡 Set GREENLIGHT_DB_DSN in your .env file"; \
		else \
			echo "  ✅ Database DSN configured"; \
		fi; \
		echo ""; \
		echo "🔧 SMTP Configuration:"; \
		source .env && echo "  Host: $${SMTP_HOST:-not set}"; \
		source .env && echo "  Port: $${SMTP_PORT:-not set}"; \
		source .env && echo "  Username: $${SMTP_USERNAME:-not set}"; \
		source .env && if [ -z "$$SMTP_HOST" ] || [ -z "$$SMTP_PORT" ] || [ -z "$$SMTP_USERNAME" ] || [ -z "$$SMTP_PASSWORD" ]; then \
			echo "  ⚠️  SMTP configuration incomplete. User registration will fail."; \
			echo "  💡 Run 'make env/smtp' for help setting up email."; \
		else \
			echo "  ✅ SMTP configuration appears complete"; \
		fi; \
		echo ""; \
		echo "🔧 Optional Configuration:"; \
		source .env && echo "  CORS Origins: $${CORS_TRUSTED_ORIGINS:-not set}"; \
		source .env && echo "  Rate Limiting: $${LIMITER_ENABLED:-not set (default: true)}"; \
		echo ""; \
		echo "💡 Configuration load order (highest to lowest priority):"; \
		echo "   1. Command-line flags"; \
		echo "   2. Environment variables"; \
		if [ -f .env.local ]; then \
			echo "   3. .env.local file (found)"; \
		else \
			echo "   3. .env.local file (create with 'make env/copy/local')"; \
		fi; \
		echo "   4. .env file"; \
	else \
		echo "⚠️  .env file not found. Run 'make env/copy' to create one."; \
	fi

## env/smtp: show SMTP configuration help
.PHONY: env/smtp
env/smtp:
	@echo "📧 SMTP Configuration Help"
	@echo ""
	@echo "SMTP is required for user registration emails. Set these in your .env file:"
	@echo ""
	@echo "For Mailtrap (development):"
	@echo "  SMTP_HOST=sandbox.smtp.mailtrap.io"
	@echo "  SMTP_PORT=2525"
	@echo "  SMTP_USERNAME=your_mailtrap_username"
	@echo "  SMTP_PASSWORD=your_mailtrap_password"
	@echo "  SMTP_SENDER='Greenlight <no-reply@greenlight.com>'"
	@echo ""
	@echo "For Gmail:"
	@echo "  SMTP_HOST=smtp.gmail.com"
	@echo "  SMTP_PORT=587"
	@echo "  SMTP_USERNAME=your-email@gmail.com"
	@echo "  SMTP_PASSWORD=your-16-character-app-password"
	@echo ""
	@echo "For SendGrid (production):"
	@echo "  SMTP_HOST=smtp.sendgrid.net"
	@echo "  SMTP_PORT=587"
	@echo "  SMTP_USERNAME=apikey"
	@echo "  SMTP_PASSWORD=your-sendgrid-api-key"
	@echo ""
	@echo "🔗 Setup guides:"
	@echo "  • Mailtrap: https://mailtrap.io"
	@echo "  • Gmail App Passwords: https://support.google.com/accounts/answer/185833"
	@echo "  • SendGrid: https://sendgrid.com"
	@echo ""
	@echo "💡 After setting up, run 'make env/check' to validate your configuration"

## db/psql: connect to the database psql
.PHONY: db/psql
db/psql:
	psql ${GREENLIGHT_DB_DSN}

## db/migration/new name=migration_name: create a new database migration
.PHONY: db/migration/new
db/migration/new:
	@echo 'Creating migration files for ${name}...'
	migrate create -seq -ext=.sql -dir=./migrations ${name}

## db/migration/up: apply all up migrations
.PHONY: db/migration/up
db/migration/up: confirm
	@echo 'Running up migration'
	migrate -path ./migrations -database ${GREENLIGHT_DB_DSN} up

## db/migration/down: apply all down migrations
.PHONY: db/migration/down
db/migration/down: confirm
	@echo 'Running down migration'
	migrate -path ./migrations -database ${GREENLIGHT_DB_DSN} down

## db/migration/up/n n=1: apply n up migrations
.PHONY: db/migration/up/n
db/migration/up/n: confirm
	@echo 'Running ${n} up migration(s)'
	migrate -path ./migrations -database ${GREENLIGHT_DB_DSN} up ${n}

## db/migration/down/n n=1: apply n down migrations
.PHONY: db/migration/down/n
db/migration/down/n: confirm
	@echo 'Running ${n} down migration(s)'
	migrate -path ./migrations -database ${GREENLIGHT_DB_DSN} down ${n}

# =============================================================================
# QUALITY CONTROL
# =============================================================================

## audit: tidy dependencies and format, vet and test all code
.PHONY: audit
audit:  vendor
	@echo 'Formatting code...'
	go fmt ./...
	@echo 'Vetting code...'
	go vet ./...
	staticcheck ./...
	@echo 'Running tests...'
	go test -race -vet=off ./...

## vendor: tidy and vendor dependencies
.PHONY: vendor
vendor:
	@echo 'Tidy and verifying module dependencies'
	go mod tidy
	go mod verify
	@echo 'Vendoring dependencies'
	go mod vendor

# =============================================================================
# DOCKER COMPOSE
# =============================================================================

## compose/up: start API and Postgres via docker compose
.PHONY: compose/up
compose/up:
	$(COMPOSE) -f $(COMPOSE_FILE) up -d --build

## compose/down: stop and remove compose services (keeps volumes)
.PHONY: compose/down
compose/down:
	$(COMPOSE) -f $(COMPOSE_FILE) down

## compose/down/v: stop and remove compose services and volumes (DB data)
.PHONY: compose/down/v
compose/down/v: confirm
	$(COMPOSE) -f $(COMPOSE_FILE) down -v

## compose/build: build the API image via compose
.PHONY: compose/build
compose/build:
	$(COMPOSE) -f $(COMPOSE_FILE) build api

## compose/restart: restart the API container
.PHONY: compose/restart
compose/restart:
	$(COMPOSE) -f $(COMPOSE_FILE) restart api

## compose/logs: tail logs for API and DB
.PHONY: compose/logs
compose/logs:
	$(COMPOSE) -f $(COMPOSE_FILE) logs -f

## compose/psql: open psql to the compose Postgres
.PHONY: compose/psql
compose/psql:
	@echo 'Opening psql to greenlight database via docker exec'
	$(COMPOSE) -f $(COMPOSE_FILE) exec db psql -U greenlight -d greenlight

## compose/health: check API health endpoint
.PHONY: compose/health
compose/health:
	@echo 'GET http://localhost:4000/v1/healthcheck'
	@curl -sS http://localhost:4000/v1/healthcheck | jq .

## compose/migrate/up: apply all up migrations inside API container
.PHONY: compose/migrate/up
compose/migrate/up:
	@echo 'Running migrations up inside API container...'
	$(COMPOSE) -f $(COMPOSE_FILE) exec api sh /app/scripts/migrate.sh up

## compose/migrate/down: apply all down migrations inside API container
.PHONY: compose/migrate/down
compose/migrate/down: confirm
	@echo 'Running migrations down inside API container...'
	$(COMPOSE) -f $(COMPOSE_FILE) exec api sh /app/scripts/migrate.sh down

## compose/migrate/version: show current migration version
.PHONY: compose/migrate/version
compose/migrate/version:
	@echo 'Checking migration version...'
	$(COMPOSE) -f $(COMPOSE_FILE) exec api sh /app/scripts/migrate.sh version

# =============================================================================
# MIGRATIONS SERVICE (docker compose)
# =============================================================================

## compose/migrations/up: run the dedicated migrations service (depends on db healthy)
.PHONY: compose/migrations/up
compose/migrations/up:
	@echo 'Starting migrations service...'
	$(COMPOSE) -f $(COMPOSE_FILE) up -d --build migrations
	@echo 'Tail migrations logs (press Ctrl+C to stop)'
	$(COMPOSE) -f $(COMPOSE_FILE) logs -f --no-color migrations || true

## compose/migrations/down: stop and remove the migrations service
.PHONY: compose/migrations/down
compose/migrations/down:
	@echo 'Stopping migrations service...'
	$(COMPOSE) -f $(COMPOSE_FILE) rm -sf migrations

## compose/migrations/rerun: rebuild and rerun the migrations service
.PHONY: compose/migrations/rerun
compose/migrations/rerun: compose/migrations/down
	@echo 'Rebuilding image and re-running migrations service...'
	$(COMPOSE) -f $(COMPOSE_FILE) build migrations
	$(COMPOSE) -f $(COMPOSE_FILE) up -d migrations
	$(COMPOSE) -f $(COMPOSE_FILE) logs -f --no-color migrations || true

# =============================================================================
# BUILD
# =============================================================================
current_time = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
git_description = $(shell git describe --always --dirty --tags --long)
linker_flags = '-s -X main.buildTime=${current_time} -X main.version=${git_description}'

## build/api: build the cmd/api application
.PHONY: build/api
build/api:
	@echo 'Building cmd/api...'
	go build -ldflags=${linker_flags} -o=./bin/api ./cmd/api
	GOOS=linux GOARCH=amd64 go build -ldflags=${linker_flags} -o=./bin/linux_amd64/api ./cmd/api
