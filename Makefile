#Include variables from the .envrc files
    include .envrc

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} |   column -t -s ':' |  sed -e 's/^/ /'

.PHONY: confirm
confirm:
	@printf 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]

## run/api: run the cmd/api application
.PHONY: run/api
run/api:
	go run ./cmd/api -db-dsn=${GREENLIGHT_DB_DSN}

## db/psql: connect to the database psql
.PHONY: db/psql
db/psql:
	psql ${GREENLIGHT_DB_DSN}

## db/migration/new: create a new database migration
.PHONY: db/migration/new
db/migration/new:
	@echo 'Creating migration files for ${name}...'
	migrate create -seq -ext=.sql -dir=./migrations ${name}

## db/migration/up: apply all up migrations
.PHONY: db/migration/up
db/migration/up: confirm
	@echo 'Running up migration'
	migrate -path ./migrations -database ${GREENLIGHT_DB_DSN} up
