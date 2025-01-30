-- Setup for pgai_main database
\c pgai_main;

-- Create test data table for load testing
CREATE TABLE IF NOT EXISTS test_data (
    id SERIAL PRIMARY KEY,
    value INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL
);

-- Create user if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'pgai_user') THEN
    CREATE USER pgai_user WITH PASSWORD 'vnp-1234';
  END IF;
END
$$;

-- Grant permissions on main database
GRANT ALL PRIVILEGES ON DATABASE pgai_main TO pgai_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO pgai_user;
GRANT USAGE ON SCHEMA public TO pgai_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO pgai_user;

-- Setup for pgai_metrics database
\c pgai_metrics;

-- Create metrics schema
CREATE SCHEMA IF NOT EXISTS metrics_history;
SET search_path TO metrics_history, public;

-- Create metrics table
CREATE TABLE IF NOT EXISTS metrics (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    connections INTEGER NOT NULL,
    transactions_per_sec FLOAT NOT NULL,
    cache_hit_ratio FLOAT NOT NULL,
    cpu_usage FLOAT NOT NULL,
    memory_usage FLOAT NOT NULL,
    iops INTEGER NOT NULL,
    active_queries INTEGER NOT NULL,
    avg_query_time FLOAT NOT NULL,
    llm_suggestions_applied BOOLEAN DEFAULT false
);

-- Create index for efficient time-based queries
CREATE INDEX IF NOT EXISTS metrics_timestamp_idx ON metrics (timestamp);

-- Create table to store LLM suggestions
CREATE TABLE IF NOT EXISTS llm_suggestions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    parameter_name VARCHAR(100) NOT NULL,
    old_value TEXT NOT NULL,
    new_value TEXT NOT NULL,
    reasoning TEXT NOT NULL,
    impact VARCHAR(10) NOT NULL,
    applied BOOLEAN DEFAULT false,
    performance_impact JSONB -- Store performance metrics before/after
);

-- Grant permissions on metrics database
GRANT ALL PRIVILEGES ON DATABASE pgai_metrics TO pgai_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA metrics_history TO pgai_user;
GRANT USAGE ON SCHEMA metrics_history TO pgai_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA metrics_history TO pgai_user;
