-- Create separate databases for main data and metrics
CREATE DATABASE pgai_main;
CREATE DATABASE pgai_metrics;

-- Create user if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'pgai_user') THEN
    CREATE USER pgai_user WITH PASSWORD 'vnp-1234';
  END IF;
END
$$;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE pgai_main TO pgai_user;
GRANT ALL PRIVILEGES ON DATABASE pgai_metrics TO pgai_user;

-- Connect to metrics database and set up schema
\c pgai_metrics

-- Create schema for metrics
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

-- Create views for aggregated metrics
CREATE OR REPLACE VIEW hourly_metrics AS
SELECT
    date_trunc('hour', timestamp) as hour,
    llm_suggestions_applied,
    round(avg(connections)::numeric, 2) as avg_connections,
    round(avg(transactions_per_sec)::numeric, 2) as avg_tps,
    round(avg(cache_hit_ratio)::numeric, 4) as avg_cache_hit_ratio,
    round(avg(cpu_usage)::numeric, 2) as avg_cpu_usage,
    round(avg(memory_usage)::numeric, 2) as avg_memory_usage,
    round(avg(iops)::numeric, 2) as avg_iops,
    round(avg(active_queries)::numeric, 2) as avg_active_queries,
    round(avg(avg_query_time)::numeric, 4) as avg_query_time
FROM metrics
GROUP BY hour, llm_suggestions_applied
ORDER BY hour DESC;

-- Create view for daily metrics
CREATE OR REPLACE VIEW daily_metrics AS
SELECT
    date_trunc('day', timestamp) as day,
    llm_suggestions_applied,
    round(avg(connections)::numeric, 2) as avg_connections,
    round(avg(transactions_per_sec)::numeric, 2) as avg_tps,
    round(avg(cache_hit_ratio)::numeric, 4) as avg_cache_hit_ratio,
    round(avg(cpu_usage)::numeric, 2) as avg_cpu_usage,
    round(avg(memory_usage)::numeric, 2) as avg_memory_usage,
    round(avg(iops)::numeric, 2) as avg_iops,
    round(avg(active_queries)::numeric, 2) as avg_active_queries,
    round(avg(avg_query_time)::numeric, 4) as avg_query_time,
    round(max(connections)::numeric, 2) as max_connections,
    round(max(cpu_usage)::numeric, 2) as max_cpu_usage,
    round(max(memory_usage)::numeric, 2) as max_memory_usage
FROM metrics
GROUP BY day, llm_suggestions_applied
ORDER BY day DESC;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA metrics_history TO pgai_user;
GRANT USAGE ON SCHEMA metrics_history TO pgai_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA metrics_history TO pgai_user;

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

GRANT ALL PRIVILEGES ON TABLE llm_suggestions TO pgai_user;
GRANT USAGE ON SEQUENCE llm_suggestions_id_seq TO pgai_user;
