-- Create metrics table
CREATE TABLE IF NOT EXISTS metrics_history (
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
CREATE INDEX IF NOT EXISTS metrics_history_timestamp_idx ON metrics_history (timestamp);

-- Create function to clean up old metrics (keep last 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_metrics()
RETURNS void AS $$
BEGIN
    DELETE FROM metrics_history
    WHERE timestamp < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled job to clean up old metrics daily
DO $$ 
BEGIN
    -- Create extension if it doesn't exist (requires superuser privileges)
    CREATE EXTENSION IF NOT EXISTS pg_cron;
    
    -- Schedule cleanup job to run daily at midnight
    SELECT cron.schedule('0 0 * * *', 'SELECT cleanup_old_metrics()');
EXCEPTION WHEN OTHERS THEN
    -- pg_cron might not be available, that's okay
    RAISE NOTICE 'Could not schedule automatic cleanup. Please run cleanup_old_metrics() manually periodically.';
END $$;

-- Create view for aggregated metrics by hour
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
FROM metrics_history
GROUP BY hour
ORDER BY hour DESC;

-- Create view for daily metrics
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
FROM metrics_history
GROUP BY day
ORDER BY day DESC;

-- Grant necessary permissions
GRANT SELECT, INSERT ON metrics_history TO pgai_user;
GRANT SELECT ON hourly_metrics TO pgai_user;
GRANT SELECT ON daily_metrics TO pgai_user;
GRANT USAGE, SELECT ON SEQUENCE metrics_history_id_seq TO pgai_user;
