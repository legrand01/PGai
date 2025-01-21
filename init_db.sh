#!/bin/bash

# Check if PostgreSQL is running
if ! pg_isready > /dev/null 2>&1; then
    echo "Error: PostgreSQL is not running"
    exit 1
fi

# Change to the script's directory
cd "$(dirname "$0")"

# Check if database exists
if ! psql -lqt | cut -d \| -f 1 | grep -qw pgai; then
    echo "Database 'pgai' does not exist. Please run these commands as superuser:"
    echo "createdb pgai"
    echo "createuser -P pgai_user  # Use password: vnp-1234"
    exit 1
fi

# Initialize schema and tables
echo "Initializing schema and tables..."
if psql -d pgai -f sql/init_db.sql; then
    echo "Schema initialization completed successfully"
else
    echo "Error: Failed to initialize schema"
    exit 1
fi

echo "Database setup completed successfully"
