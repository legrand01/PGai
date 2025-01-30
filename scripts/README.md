# PGai Load Testing Scripts

This directory contains scripts for load testing PostgreSQL with PGai's LLM-powered suggestions.

## Setup

1. Install Python dependencies:
```bash
pip install -r requirements.txt
```

2. Ensure PostgreSQL is running and you have superuser access.

## Running the Tests

You can run the complete test suite using the setup script:

```bash
./setup_and_test.sh
```

This will:
1. Create separate databases for main data and metrics
2. Start the PGai server to generate LLM suggestions
3. Run two load tests:
   - First test: Get LLM suggestions but don't apply them
   - Second test: Get LLM suggestions and apply them
4. Generate detailed comparison metrics

### Manual Testing

You can also run the load test script directly with custom parameters:

```bash
python3 load_test.py --duration 300 --users 10
```

Parameters:
- `--duration`: Test duration in seconds (default: 300)
- `--users`: Number of concurrent users (default: 10)

## Test Results

Results are saved in the `results` directory with timestamps. Each result file contains:
- Query statistics (count, average time, min/max times, 95th percentile)
- System metrics (CPU, memory, IOPS, cache hit ratio)
- Comparison between runs with and without LLM suggestions applied

The results show how the database performs in both scenarios:
1. When LLM suggestions are received but not applied (baseline)
2. When LLM suggestions are received and applied

This helps evaluate the effectiveness of PGai's configuration recommendations.
