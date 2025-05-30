# Include variables from the .envrc files
include .envrc

# =============================================================================
# HELPERS
# =============================================================================

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} |   column -t -s ':' |  sed -e 's/^/ /'

.PHONY: confirm
confirm:
	@printf 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]

# =============================================================================
# DEVELOPMENT
# =============================================================================

## run/api: run the cmd/api application
.PHONY: run/api
run/api:
	go run ./cmd/api -db-dsn=${GREENLIGHT_DB_DSN}

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
audit:
	@echo 'Tidy and verifying module dependencies'
	go mod tidy
	go mod verify
	@echo 'Formatting code...'
	go fmt ./...
	@echo 'Vetting code...'
	go vet ./...
	staticcheck ./...
	@echo 'Running tests...'
	go test -race -vet=off ./...
