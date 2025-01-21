-- Note: Run these commands as superuser if needed:
/*
CREATE DATABASE pgai;
CREATE USER pgai_user WITH PASSWORD 'vnp-1234';
*/

-- Create schema and tables in the metrics_history namespace
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
    avg_query_time FLOAT NOT NULL
);

-- Create index for efficient time-based queries
CREATE INDEX IF NOT EXISTS metrics_timestamp_idx ON metrics (timestamp);

-- Create function to clean up old metrics (keep last 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_metrics()
RETURNS void AS $$
BEGIN
    DELETE FROM metrics
    WHERE timestamp < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Create views for aggregated metrics
CREATE OR REPLACE VIEW hourly_metrics AS
SELECT
    date_trunc('hour', timestamp) as hour,
    round(avg(connections)::numeric, 2) as avg_connections,
    round(avg(transactions_per_sec)::numeric, 2) as avg_tps,
    round(avg(cache_hit_ratio)::numeric, 4) as avg_cache_hit_ratio,
    round(avg(cpu_usage)::numeric, 2) as avg_cpu_usage,
    round(avg(memory_usage)::numeric, 2) as avg_memory_usage,
    round(avg(iops)::numeric, 2) as avg_iops,
    round(avg(active_queries)::numeric, 2) as avg_active_queries,
    round(avg(avg_query_time)::numeric, 4) as avg_query_time
FROM metrics
GROUP BY hour
ORDER BY hour DESC;

CREATE OR REPLACE VIEW daily_metrics AS
SELECT
    date_trunc('day', timestamp) as day,
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
GROUP BY day
ORDER BY day DESC;

-- Schedule cleanup (requires pg_cron extension)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
    ) THEN
        SELECT cron.schedule('cleanup-metrics', '0 0 * * *', 'SELECT cleanup_old_metrics()');
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- pg_cron not available, skip scheduling
    NULL;
END $$;
