#!/bin/sh

set -e

# Migration script using psql directly
# Usage: ./migrate.sh up|down|version

MIGRATIONS_DIR="/app/migrations"
DATABASE_URL=${DATABASE_URL:-""}

if [ -z "$DATABASE_URL" ]; then
    echo "Error: DATABASE_URL environment variable is required" >&2
    exit 1
fi

# Initialize schema_migrations table if it doesn't exist
init_schema_migrations() {
    psql "$DATABASE_URL" -c "CREATE TABLE IF NOT EXISTS schema_migrations (version bigint NOT NULL PRIMARY KEY, dirty boolean NOT NULL);" > /dev/null
}

# Get current migration version
get_current_version() {
    init_schema_migrations
    psql "$DATABASE_URL" -t -c "SELECT COALESCE(MAX(version), 0) FROM schema_migrations WHERE NOT dirty;" 2>/dev/null | xargs
}

# Get all available migration versions
get_available_versions() {
    find "$MIGRATIONS_DIR" -name "*.up.sql" | sed 's/.*\/\([0-9]\{6\}\)_.*/\1/' | sort -n
}

# Run migrations up
migrate_up() {
    echo "Running database migrations..."
    init_schema_migrations

    current_version=$(get_current_version)
    echo "Current version: $current_version"

    for version in $(get_available_versions); do
        if [ "$version" -gt "$current_version" ]; then
            echo "Applying migration $version..."

            # Mark as dirty
            psql "$DATABASE_URL" -c "INSERT INTO schema_migrations (version, dirty) VALUES ($version, true) ON CONFLICT (version) DO UPDATE SET dirty = true;" > /dev/null

            # Find the migration file
            migration_file=$(find "$MIGRATIONS_DIR" -name "${version}_*.up.sql" | head -1)

            if [ -f "$migration_file" ]; then
                echo "Running: $(basename "$migration_file")"
                psql "$DATABASE_URL" -f "$migration_file"

                # Mark as clean
                psql "$DATABASE_URL" -c "UPDATE schema_migrations SET dirty = false WHERE version = $version;" > /dev/null
                echo "✓ Migration $version applied successfully"
            else
                echo "Error: Migration file for version $version not found" >&2
                exit 1
            fi
        fi
    done

    echo "All migrations completed successfully"
}

# Run migrations down
migrate_down() {
    echo "Rolling back database migrations..."
    init_schema_migrations

    current_version=$(get_current_version)
    echo "Current version: $current_version"

    if [ "$current_version" -eq 0 ]; then
        echo "No migrations to roll back"
        return
    fi

    echo "Rolling back migration $current_version..."

    # Mark as dirty
    psql "$DATABASE_URL" -c "UPDATE schema_migrations SET dirty = true WHERE version = $current_version;" > /dev/null

    # Find the down migration file
    migration_file=$(find "$MIGRATIONS_DIR" -name "${current_version}_*.down.sql" | head -1)

    if [ -f "$migration_file" ]; then
        echo "Running: $(basename "$migration_file")"
        psql "$DATABASE_URL" -f "$migration_file"

        # Remove from schema_migrations
        psql "$DATABASE_URL" -c "DELETE FROM schema_migrations WHERE version = $current_version;" > /dev/null
        echo "✓ Migration $current_version rolled back successfully"
    else
        echo "Error: Down migration file for version $current_version not found" >&2
        exit 1
    fi
}

# Show current version
show_version() {
    init_schema_migrations
    current_version=$(get_current_version)

    # Check for dirty state
    dirty_count=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM schema_migrations WHERE dirty;" 2>/dev/null | xargs)

    if [ "$dirty_count" -gt 0 ]; then
        echo "$current_version (dirty)"
    else
        echo "$current_version"
    fi
}

# Main command handling
case "${1:-}" in
    "up")
        migrate_up
        ;;
    "down")
        migrate_down
        ;;
    "version")
        show_version
        ;;
    *)
        echo "Usage: $0 {up|down|version}"
        echo ""
        echo "Commands:"
        echo "  up      Apply all pending migrations"
        echo "  down    Roll back the latest migration"
        echo "  version Show current migration version"
        exit 1
        ;;
esac
