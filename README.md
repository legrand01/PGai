# PGai - PostgreSQL Monitoring and Load Testing Tool

PGai is a comprehensive PostgreSQL monitoring and load testing tool that combines the capabilities of dbtune with additional AI-powered features. It provides both an MCP server for real-time monitoring and a suite of SQL scripts for load testing.

## Project Structure

- `src/index.ts` - MCP server implementation for real-time PostgreSQL monitoring
- `schema.sql` - Database schema for load testing environment
- `generate_data.sql` - Functions to generate test data
- `load_test_queries.sql` - Complex queries for performance testing
- `run_load_test.sql` - Load test execution and benchmarking functions

## Setup

1. Create the PostgreSQL database:
```sql
CREATE DATABASE pgai;
```

2. Initialize the schema:
```sql
\i schema.sql
```

3. Generate test data:
```sql
-- Generate 1000 users, 500 products, and 2000 orders
SELECT generate_test_data(1000, 500, 2000, 1, 5);
```

4. Load the test queries and benchmarking functions:
```sql
\i load_test_queries.sql
\i run_load_test.sql
```

## Available Load Tests

The environment includes several types of performance tests:

1. Full-text Search
   - Tests PostgreSQL's text search capabilities
   - Uses GIN indexes and text search vectors

2. User Spending Analysis
   - Complex aggregations with window functions
   - Tests JOIN performance and analytical queries

3. Product Performance Analysis
   - Multi-table joins with conditional logic
   - Tests database's ability to handle complex business logic

4. Customer Segmentation
   - Advanced analytics with CTEs
   - Tests performance of customer analytics queries

5. Inventory Analysis
   - Moving averages and time-series analysis
   - Tests window functions and date/time operations

6. Complex Category Analysis
   - Multiple joins and aggregations
   - Tests overall query optimizer performance

## Running Load Tests

1. Run a complete load test with default settings:
```sql
SELECT * FROM run_load_test();
```

2. Run a formatted load test with custom iterations:
```sql
SELECT format_load_test_results(20);  -- Run 20 iterations
```

## MCP Server Features

The PGai MCP server provides:

1. Real-time Monitoring
   - Connection counts
   - Query performance metrics
   - Cache hit ratios
   - System resource usage

2. Performance Analysis
   - Historical performance tracking
   - AI-powered recommendations
   - Configuration optimization

3. Configuration Management
   - View current settings
   - Update configuration parameters
   - Track configuration changes

## Using the MCP Server

1. Connect to a database:
```
use_mcp_tool with:
server_name: PGai
tool_name: connect_database
arguments: {
  "host": "localhost",
  "port": 5432,
  "database": "pgai",
  "user": "your_username",
  "password": "your_password"
}
```

2. Get performance metrics:
```
use_mcp_tool with:
server_name: PGai
tool_name: get_performance_metrics
```

3. Analyze performance:
```
use_mcp_tool with:
server_name: PGai
tool_name: analyze_performance
arguments: {
  "timeRange": "1h"
}
```

## Schema Details

The test environment includes several interconnected tables:

- `users` - User accounts with preferences
- `products` - Product catalog with text search
- `orders` - Customer orders with status tracking
- `order_items` - Individual items within orders
- `reviews` - Product reviews with text search
- `inventory_transactions` - Inventory movements
- `product_stats` - Materialized view for analytics

Each table includes appropriate indexes and constraints for optimal performance testing.

## Best Practices

1. Reset the database state between major test runs
2. Monitor system resources during load tests
3. Use EXPLAIN ANALYZE to investigate slow queries
4. Regularly VACUUM and ANALYZE tables
5. Refresh materialized views as needed

## Contributing

Feel free to submit issues and enhancement requests!
