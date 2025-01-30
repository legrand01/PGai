#!/bin/bash

# Exit on any error
set -e

echo "Setting up databases..."

# Run setup script to create databases
psql -U postgres -f ../sql/setup_databases.sql

echo "Waiting for databases to be ready..."
sleep 5

# Start the PGai server to get LLM suggestions
echo "Starting PGai server to generate suggestions..."
cd ..
npm run start:mcp &
PID=$!

# Wait for suggestions to be generated
echo "Waiting for LLM to analyze and generate suggestions (30 seconds)..."
sleep 30

echo "Running load tests..."
cd scripts
python3 load_test.py --duration 300 --users 10

# Clean up
echo "Cleaning up..."
kill $PID

echo "Tests completed. Check the results directory for detailed metrics."
