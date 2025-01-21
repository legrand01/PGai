# PGai - PostgreSQL Performance Monitoring and AI-Powered Tuning

PGai is a real-time PostgreSQL monitoring and performance tuning tool that combines traditional metrics collection with AI-powered recommendations. It provides a modern web dashboard for visualizing database performance and automated suggestions for optimization.

## Features

### Real-time Monitoring
- Active connections tracking
- Transaction throughput measurement
- Buffer cache hit ratio analysis
- CPU and memory utilization
- I/O operations per second (IOPS)
- Active queries count
- Query execution time analysis

### Historical Analysis
- Persistent metrics storage in PostgreSQL
- Automatic data retention (30-day history)
- Hourly and daily aggregated views
- Time-series performance graphs
- Trend analysis capabilities

### AI-Powered Recommendations
- Automatic configuration suggestions
- Performance bottleneck detection
- Resource utilization optimization
- Connection pooling recommendations
- Cache efficiency improvements

## Architecture

### Components

1. **MCP Server**
   - Core metrics collection engine
   - AI-powered analysis system
   - PostgreSQL connection management
   - Real-time monitoring service
   - HTTP API for dashboard communication

2. **Dashboard Server**
   - Express.js web server
   - Real-time metrics display
   - Interactive performance graphs
   - Configuration management interface

3. **PostgreSQL Storage**
   - Metrics history schema
   - Aggregated performance views
   - Automatic data cleanup
   - Efficient time-series queries

### Data Flow
1. MCP server collects metrics from target PostgreSQL database
2. Metrics are stored in the metrics_history schema
3. Dashboard queries metrics through MCP server's HTTP API
4. AI analysis runs on collected metrics
5. Recommendations are generated and displayed

## Setup

### Prerequisites
- Node.js v16 or higher
- PostgreSQL 12 or higher
- npm or yarn package manager

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd pgai
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Build the TypeScript code:
   ```bash
   npm run build
   ```

4. Initialize the database:
   ```bash
   ./init_db.sh
   ```

5. Start the servers:
   ```bash
   ./start.sh
   ```

### Configuration

#### Database Connection
Environment variables for database connection:
- `PGHOST`: PostgreSQL host (default: localhost)
- `PGPORT`: PostgreSQL port (default: 5432)
- `PGDATABASE`: Database name (default: pgai)
- `PGUSER`: Database user (default: pgai_user)
- `PGPASSWORD`: Database password

#### PostgreSQL Configuration
For detailed information about PostgreSQL configuration, including:
- Configuration file locations
- Important parameters
- Modification methods
- Backup procedures
- Best practices
- Troubleshooting

See [PostgreSQL Configuration Guide](docs/postgres_config.md)

## Database Schema

### Tables

#### metrics_history.metrics
```sql
CREATE TABLE metrics_history.metrics (
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
```

### Views

#### hourly_metrics
Provides hourly aggregated metrics including:
- Average connections
- Average transactions per second
- Average cache hit ratio
- Average CPU and memory usage
- Average IOPS

#### daily_metrics
Provides daily aggregated metrics including:
- Daily averages of all metrics
- Maximum connections
- Peak CPU and memory usage

## API Reference

### MCP Server Endpoints

#### POST /mcp
Handles all MCP tool requests including:

1. get_performance_metrics
   ```json
   {
     "method": "callTool",
     "params": {
       "name": "get_performance_metrics",
       "arguments": {}
     }
   }
   ```

2. analyze_performance
   ```json
   {
     "method": "callTool",
     "params": {
       "name": "analyze_performance",
       "arguments": {
         "timeRange": "24h"
       }
     }
   }
   ```

3. get_config
   ```json
   {
     "method": "callTool",
     "params": {
       "name": "get_config",
       "arguments": {}
     }
   }
   ```

### Dashboard Server Endpoints

#### GET /api/metrics
Returns current performance metrics

#### GET /api/analyze
Returns performance analysis and recommendations
- Query parameter: timeRange (e.g., "1h", "24h", "7d")

#### GET /api/config
Returns current PostgreSQL configuration

## Development

### Project Structure
```
pgai/
├── src/               # TypeScript source files
├── build/            # Compiled JavaScript
├── dashboard/        # Web dashboard
│   ├── server.js    # Dashboard server
│   ├── index.html   # Dashboard UI
│   └── dashboard.js # Dashboard logic
├── sql/             # Database scripts
│   ├── init_db.sql      # Database initialization
│   └── metrics_schema.sql # Metrics schema
└── scripts/         # Utility scripts
```

### Building
```bash
npm run build        # Build TypeScript
npm run watch        # Watch mode for development
```

### Testing
```bash
npm test            # Run test suite
```

## Maintenance

### Data Retention
- Metrics are automatically cleaned up after 30 days
- Cleanup runs daily at midnight via pg_cron
- Manual cleanup: `SELECT cleanup_old_metrics();`

### Monitoring
- Check dashboard connectivity
- Monitor metrics collection
- Verify database connections
- Review error logs

## Troubleshooting

### Common Issues

1. Connection Errors
   - Verify PostgreSQL is running
   - Check connection credentials
   - Confirm network connectivity

2. Missing Metrics
   - Verify MCP server status
   - Check database permissions
   - Review error logs

3. Dashboard Issues
   - Confirm both servers are running
   - Check browser console for errors
   - Verify API endpoints

## License

MIT License - See LICENSE file for details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Support

For issues and feature requests, please use the GitHub issue tracker.
