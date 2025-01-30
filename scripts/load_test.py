import psycopg2
import time
import concurrent.futures
import random
import statistics
import json
from datetime import datetime
import os
import argparse
from typing import Dict, List, Optional, Tuple

# Database connection parameters
MAIN_DB_PARAMS = {
    'dbname': 'pgai_main',
    'user': 'pgai_user',
    'password': 'vnp-1234',
    'host': 'localhost',
    'port': '5432'
}

METRICS_DB_PARAMS = {
    'dbname': 'pgai_metrics',
    'user': 'pgai_user',
    'password': 'vnp-1234',
    'host': 'localhost',
    'port': '5432'
}

def get_llm_suggestions() -> List[Tuple[str, str, str]]:
    """Get current LLM suggestions from metrics database"""
    conn = psycopg2.connect(**METRICS_DB_PARAMS)
    cur = conn.cursor()
    try:
        cur.execute("""
            SELECT parameter_name, new_value, reasoning
            FROM metrics_history.llm_suggestions
            WHERE applied = false
            ORDER BY timestamp DESC
            LIMIT 5
        """)
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()

def apply_llm_suggestions(suggestions: List[Tuple[str, str, str]]) -> None:
    """Apply LLM suggestions to the database"""
    conn = psycopg2.connect(**MAIN_DB_PARAMS)
    cur = conn.cursor()
    try:
        for param, value, _ in suggestions:
            cur.execute("ALTER SYSTEM SET %s = %s", (param, value))
        
        # Reload configuration
        cur.execute("SELECT pg_reload_conf()")
        conn.commit()
        
        # Mark suggestions as applied
        metrics_conn = psycopg2.connect(**METRICS_DB_PARAMS)
        metrics_cur = metrics_conn.cursor()
        try:
            for param, value, _ in suggestions:
                metrics_cur.execute("""
                    UPDATE metrics_history.llm_suggestions 
                    SET applied = true 
                    WHERE parameter_name = %s AND new_value = %s
                """, (param, value))
            metrics_conn.commit()
        finally:
            metrics_cur.close()
            metrics_conn.close()
    finally:
        cur.close()
        conn.close()

def execute_query(query_type: str, suggestions_applied: bool) -> Optional[float]:
    """Execute a random query based on type"""
    conn = psycopg2.connect(**MAIN_DB_PARAMS)
    cur = conn.cursor()
    start_time = time.time()
    
    try:
        if query_type == "select":
            # Complex SELECT query with window functions and aggregates
            cur.execute("""
                WITH recent_data AS (
                    SELECT 
                        value,
                        created_at,
                        AVG(value) OVER (
                            ORDER BY created_at 
                            ROWS BETWEEN 10 PRECEDING AND CURRENT ROW
                        ) as moving_avg,
                        ROW_NUMBER() OVER (ORDER BY created_at DESC) as rn
                    FROM test_data
                    WHERE created_at >= NOW() - interval '1 day'
                )
                SELECT 
                    COUNT(*) as total_count,
                    AVG(value) as avg_value,
                    MIN(value) as min_value,
                    MAX(value) as max_value,
                    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY value) as p95_value,
                    AVG(moving_avg) as avg_moving_avg
                FROM recent_data
                WHERE rn <= 1000
            """)
            cur.fetchall()
        elif query_type == "insert":
            # INSERT query with random values
            cur.execute("""
                WITH RECURSIVE t(n) AS (
                    SELECT 1
                    UNION ALL
                    SELECT n + 1 FROM t WHERE n < %s
                )
                INSERT INTO test_data (value, created_at)
                SELECT 
                    floor(random() * 1000000)::integer,
                    NOW() - (random() * interval '1 day')
                FROM t
            """, (random.randint(1, 100),))
            conn.commit()
        
        execution_time = time.time() - start_time
        
        # Record metrics
        metrics_conn = psycopg2.connect(**METRICS_DB_PARAMS)
        metrics_cur = metrics_conn.cursor()
        try:
            metrics_cur.execute("""
                INSERT INTO metrics_history.metrics (
                    connections, transactions_per_sec, cache_hit_ratio,
                    cpu_usage, memory_usage, iops, active_queries,
                    avg_query_time, llm_suggestions_applied
                ) VALUES (
                    (SELECT count(*) FROM pg_stat_activity),
                    (SELECT xact_commit + xact_rollback FROM pg_stat_database WHERE datname = %s),
                    (SELECT COALESCE(sum(heap_blks_hit)::float / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0), 0) FROM pg_statio_user_tables),
                    50, -- Simulated CPU usage
                    50, -- Simulated memory usage
                    1000, -- Simulated IOPS
                    (SELECT count(*) FROM pg_stat_activity WHERE state = 'active'),
                    %s,
                    %s
                )
            """, (MAIN_DB_PARAMS['dbname'], execution_time, suggestions_applied))
            metrics_conn.commit()
        finally:
            metrics_cur.close()
            metrics_conn.close()
        
        return execution_time
        
    except Exception as e:
        print(f"Error executing {query_type} query: {e}")
        return None
    finally:
        cur.close()
        conn.close()

def run_load_test(duration: int, concurrent_users: int, apply_suggestions: bool = False) -> Dict[str, Dict[str, float]]:
    """Run load test for specified duration with concurrent users"""
    print(f"\nStarting load test with {concurrent_users} concurrent users for {duration} seconds")
    print(f"LLM suggestions will{' ' if apply_suggestions else ' NOT '}be applied")
    
    # Get LLM suggestions in both cases
    suggestions = get_llm_suggestions()
    if suggestions:
        print("\nLLM suggestions:")
        for param, value, reasoning in suggestions:
            print(f"- {param} = {value} ({reasoning})")
        
        if apply_suggestions:
            print("\nApplying suggestions...")
            apply_llm_suggestions(suggestions)
        else:
            print("\nSkipping suggestion application (running in observation mode)")
    
    end_time = time.time() + duration
    results: Dict[str, List[float]] = {
        'select': [],
        'insert': []
    }
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrent_users) as executor:
        while time.time() < end_time:
            # Mix of SELECT (70%) and INSERT (30%) queries
            query_types = ['select'] * 7 + ['insert'] * 3
            futures_to_types = {
                executor.submit(execute_query, query_type, apply_suggestions): query_type
                for query_type in query_types
            }
            
            for future in concurrent.futures.as_completed(futures_to_types):
                result = future.result()
                query_type = futures_to_types[future]
                if result is not None:
                    results[query_type].append(result)
    
    # Calculate statistics
    stats = {}
    for query_type in ['select', 'insert']:
        if results[query_type]:
            stats[query_type] = {
                'count': len(results[query_type]),
                'avg_time': statistics.mean(results[query_type]),
                'min_time': min(results[query_type]),
                'max_time': max(results[query_type]),
                'p95_time': sorted(results[query_type])[int(len(results[query_type]) * 0.95)]
            }
    
    return stats

def save_results(stats: Dict[str, Dict[str, float]], test_params: Dict[str, int]) -> str:
    """Save test results to a JSON file"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    result_dir = os.path.join(os.path.dirname(__file__), 'results')
    os.makedirs(result_dir, exist_ok=True)
    
    filename = f"load_test_{timestamp}.json"
    result_path = os.path.join(result_dir, filename)
    
    # Get aggregated metrics from the test period
    conn = psycopg2.connect(**METRICS_DB_PARAMS)
    cur = conn.cursor()
    try:
        cur.execute("""
            SELECT 
                llm_suggestions_applied,
                round(avg(cpu_usage)::numeric, 2) as avg_cpu,
                round(avg(memory_usage)::numeric, 2) as avg_memory,
                round(avg(iops)::numeric, 2) as avg_iops,
                round(avg(cache_hit_ratio)::numeric, 4) as avg_cache_hit,
                round(avg(avg_query_time)::numeric, 4) as avg_query_time
            FROM metrics_history.metrics
            WHERE timestamp >= NOW() - interval '%s seconds'
            GROUP BY llm_suggestions_applied
        """, (test_params['duration'],))
        metrics_stats = cur.fetchall()
    finally:
        cur.close()
        conn.close()
    
    full_results = {
        'timestamp': timestamp,
        'parameters': test_params,
        'query_statistics': stats,
        'system_metrics': {
            'suggestions_applied' if row[0] else 'suggestions_not_applied': {
                'avg_cpu_usage': float(row[1]),
                'avg_memory_usage': float(row[2]),
                'avg_iops': float(row[3]),
                'avg_cache_hit_ratio': float(row[4]),
                'avg_query_time': float(row[5])
            }
            for row in metrics_stats
        }
    }
    
    with open(result_path, 'w') as f:
        json.dump(full_results, f, indent=2)
    
    print(f"\nResults saved to {result_path}")
    return result_path

def print_results(stats: Dict[str, Dict[str, float]], test_params: Dict[str, int]) -> None:
    """Print test results in a readable format"""
    print("\nTest Results:")
    print("=" * 50)
    
    for query_type, data in stats.items():
        print(f"\n{query_type.upper()} Queries:")
        print(f"Total queries: {data['count']}")
        print(f"Average time: {data['avg_time']:.3f} seconds")
        print(f"Min time: {data['min_time']:.3f} seconds")
        print(f"Max time: {data['max_time']:.3f} seconds")
        print(f"95th percentile: {data['p95_time']:.3f} seconds")
    
    # Print system metrics comparison if available
    conn = psycopg2.connect(**METRICS_DB_PARAMS)
    cur = conn.cursor()
    try:
        cur.execute("""
            SELECT 
                llm_suggestions_applied,
                round(avg(cpu_usage)::numeric, 2) as avg_cpu,
                round(avg(memory_usage)::numeric, 2) as avg_memory,
                round(avg(cache_hit_ratio)::numeric, 4) as avg_cache_hit,
                round(avg(avg_query_time)::numeric, 4) as avg_query_time
            FROM metrics_history.metrics
            WHERE timestamp >= NOW() - interval '%s seconds'
            GROUP BY llm_suggestions_applied
        """, (test_params['duration'],))
        
        results = cur.fetchall()
        if len(results) == 2:  # We have both applied and non-applied results
            print("\nSystem Metrics Comparison:")
            print("=" * 50)
            applied_metrics = next(r for r in results if r[0])  # Suggestions applied
            no_applied_metrics = next(r for r in results if not r[0])  # Suggestions not applied
            
            metrics = [
                ('CPU Usage', 1),
                ('Memory Usage', 2),
                ('Cache Hit Ratio', 3),
                ('Average Query Time', 4)
            ]
            
            for metric_name, idx in metrics:
                old_val = float(no_applied_metrics[idx])
                new_val = float(applied_metrics[idx])
                change_pct = ((new_val - old_val) / old_val) * 100
                print(f"\n{metric_name}:")
                print(f"- Without applying suggestions: {old_val:.2f}")
                print(f"- With suggestions applied: {new_val:.2f}")
                print(f"- Change: {change_pct:+.1f}%")
    finally:
        cur.close()
        conn.close()

def main() -> None:
    parser = argparse.ArgumentParser(description='Run database load test')
    parser.add_argument('--duration', type=int, default=300, help='Test duration in seconds')
    parser.add_argument('--users', type=int, default=10, help='Number of concurrent users')
    args = parser.parse_args()

    test_params = {
        'duration': args.duration,
        'concurrent_users': args.users
    }
    
    # Initialize test table in main database
    conn = psycopg2.connect(**MAIN_DB_PARAMS)
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS test_data (
                id SERIAL PRIMARY KEY,
                value INTEGER NOT NULL,
                created_at TIMESTAMP NOT NULL
            )
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()
    
    # Run test without applying suggestions
    print("\nRunning load test WITHOUT applying LLM suggestions...")
    stats_without_apply = run_load_test(
        test_params['duration'],
        test_params['concurrent_users'],
        apply_suggestions=False
    )
    print_results(stats_without_apply, test_params)
    save_results(stats_without_apply, {**test_params, 'suggestions_applied': False})
    
    # Wait for system to stabilize
    print("\nWaiting 60 seconds for system to stabilize...")
    time.sleep(60)
    
    # Run test with suggestions applied
    print("\nRunning load test WITH LLM suggestions applied...")
    stats_with_apply = run_load_test(
        test_params['duration'],
        test_params['concurrent_users'],
        apply_suggestions=True
    )
    print_results(stats_with_apply, test_params)
    save_results(stats_with_apply, {**test_params, 'suggestions_applied': True})

if __name__ == "__main__":
    main()
