import psycopg2
import time
import concurrent.futures
import random
from typing import List
import os
import multiprocessing

# Database connection parameters
DB_PARAMS = {
    'dbname': 'pgai',
    'user': 'pgai_user',
    'password': 'vnp-1234',
    'host': 'localhost',
    'port': '5432'
}

def cpu_intensive_task():
    """Generate CPU load with matrix operations"""
    matrix_size = 300
    matrix_a = [[random.random() for _ in range(matrix_size)] for _ in range(matrix_size)]
    matrix_b = [[random.random() for _ in range(matrix_size)] for _ in range(matrix_size)]
    result = [[sum(a * b for a, b in zip(row_a, col_b)) 
               for col_b in zip(*matrix_b)] 
               for row_a in matrix_a]
    return result

def memory_intensive_task():
    """Generate memory load by creating large lists"""
    large_list = [random.random() for _ in range(1000000)]
    sorted_list = sorted(large_list)
    return len(sorted_list)

def db_connection_task():
    """Create database connections and execute simple queries"""
    try:
        conn = psycopg2.connect(**DB_PARAMS)
        cur = conn.cursor()
        
        # Create a test table if it doesn't exist
        cur.execute("""
            CREATE TABLE IF NOT EXISTS load_test_table (
                id SERIAL PRIMARY KEY,
                data TEXT
            )
        """)
        conn.commit()

        # Execute some queries
        for _ in range(10):
            data = ''.join(random.choices('abcdefghijklmnopqrstuvwxyz', k=1000))
            cur.execute("INSERT INTO load_test_table (data) VALUES (%s)", (data,))
            cur.execute("SELECT * FROM load_test_table ORDER BY RANDOM() LIMIT 100")
            cur.fetchall()
            conn.commit()
            time.sleep(0.1)  # Small delay to maintain connection

    except Exception as e:
        print(f"Database error: {e}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

def run_load_test(duration: int, concurrent_tasks: int):
    """Run the load test with specified duration and concurrency"""
    end_time = time.time() + duration
    print(f"\nStarting load test with {concurrent_tasks} concurrent tasks for {duration} seconds")
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrent_tasks) as executor:
        while time.time() < end_time:
            # Mix of CPU, memory, and database tasks
            tasks = []
            for _ in range(concurrent_tasks):
                task_type = random.choice(['cpu', 'memory', 'db'])
                if task_type == 'cpu':
                    tasks.append(executor.submit(cpu_intensive_task))
                elif task_type == 'memory':
                    tasks.append(executor.submit(memory_intensive_task))
                else:
                    tasks.append(executor.submit(db_connection_task))
            
            # Wait for all tasks to complete
            concurrent.futures.wait(tasks)

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description='Run server load test')
    parser.add_argument('--duration', type=int, default=300, help='Test duration in seconds')
    parser.add_argument('--tasks', type=int, default=multiprocessing.cpu_count() * 2, 
                       help='Number of concurrent tasks')
    args = parser.parse_args()

    try:
        run_load_test(args.duration, args.tasks)
    except KeyboardInterrupt:
        print("\nLoad test interrupted by user")
    except Exception as e:
        print(f"\nError during load test: {e}")
