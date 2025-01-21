-- Function to run and measure query performance
CREATE OR REPLACE FUNCTION run_load_test(
    num_iterations INT DEFAULT 10,
    parallel_clients INT DEFAULT 1
) RETURNS TABLE (
    test_name TEXT,
    avg_duration_ms DECIMAL(10,2),
    min_duration_ms DECIMAL(10,2),
    max_duration_ms DECIMAL(10,2),
    total_rows BIGINT,
    iterations_completed INT
) AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    duration_ms DECIMAL(10,2);
    test_results RECORD;
    iteration INT;
BEGIN
    -- Create temporary table to store test results
    CREATE TEMP TABLE IF NOT EXISTS test_results (
        test_name TEXT,
        duration_ms DECIMAL(10,2),
        rows_affected BIGINT,
        iteration_num INT
    );

    -- Run each test multiple times
    FOR iteration IN 1..num_iterations LOOP
        -- Test 1: Full-text search
        start_time := clock_timestamp();
        PERFORM * FROM search_products('wireless');
        end_time := clock_timestamp();
        duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
        INSERT INTO test_results VALUES (
            'Full-text Search',
            duration_ms,
            (SELECT COUNT(*) FROM search_products('wireless')),
            iteration
        );

        -- Test 2: User spending analysis
        start_time := clock_timestamp();
        PERFORM * FROM analyze_user_spending();
        end_time := clock_timestamp();
        duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
        INSERT INTO test_results VALUES (
            'User Spending Analysis',
            duration_ms,
            (SELECT COUNT(*) FROM analyze_user_spending()),
            iteration
        );

        -- Test 3: Product performance
        start_time := clock_timestamp();
        PERFORM * FROM analyze_product_performance(30);
        end_time := clock_timestamp();
        duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
        INSERT INTO test_results VALUES (
            'Product Performance Analysis',
            duration_ms,
            (SELECT COUNT(*) FROM analyze_product_performance(30)),
            iteration
        );

        -- Test 4: Customer segmentation
        start_time := clock_timestamp();
        PERFORM * FROM segment_customers();
        end_time := clock_timestamp();
        duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
        INSERT INTO test_results VALUES (
            'Customer Segmentation',
            duration_ms,
            (SELECT COUNT(*) FROM segment_customers()),
            iteration
        );

        -- Test 5: Inventory analysis
        start_time := clock_timestamp();
        PERFORM * FROM analyze_inventory_trends(7);
        end_time := clock_timestamp();
        duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
        INSERT INTO test_results VALUES (
            'Inventory Analysis',
            duration_ms,
            (SELECT COUNT(*) FROM analyze_inventory_trends(7)),
            iteration
        );

        -- Test 6: Complex category analysis
        start_time := clock_timestamp();
        WITH category_analysis AS (
            SELECT 
                c.category,
                COUNT(DISTINCT o.order_id) as total_orders,
                COUNT(DISTINCT u.user_id) as unique_customers,
                ROUND(AVG(oi.price_at_time), 2) as avg_price,
                SUM(oi.quantity) as total_units_sold,
                ROUND(AVG(r.rating), 2) as avg_rating
            FROM products p
            JOIN (SELECT DISTINCT category FROM products) c ON p.category = c.category
            LEFT JOIN order_items oi ON p.product_id = oi.product_id
            LEFT JOIN orders o ON oi.order_id = o.order_id
            LEFT JOIN users u ON o.user_id = u.user_id
            LEFT JOIN reviews r ON p.product_id = r.product_id
            GROUP BY c.category
        )
        SELECT * FROM category_analysis;
        end_time := clock_timestamp();
        duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
        INSERT INTO test_results VALUES (
            'Complex Category Analysis',
            duration_ms,
            (SELECT COUNT(DISTINCT category) FROM products),
            iteration
        );
    END LOOP;

    -- Return aggregated results
    RETURN QUERY
    SELECT 
        tr.test_name,
        ROUND(AVG(tr.duration_ms), 2) as avg_duration_ms,
        ROUND(MIN(tr.duration_ms), 2) as min_duration_ms,
        ROUND(MAX(tr.duration_ms), 2) as max_duration_ms,
        MAX(tr.rows_affected) as total_rows,
        COUNT(DISTINCT tr.iteration_num) as iterations_completed
    FROM test_results tr
    GROUP BY tr.test_name
    ORDER BY avg_duration_ms DESC;

    -- Clean up
    DROP TABLE test_results;
END;
$$ LANGUAGE plpgsql;

-- Example usage:
-- Initialize database with test data:
-- SELECT generate_test_data(1000, 500, 2000, 1, 5);

-- Run load test with 10 iterations:
-- SELECT * FROM run_load_test(10);

-- Helper function to format load test results nicely
CREATE OR REPLACE FUNCTION format_load_test_results(iterations INT DEFAULT 10)
RETURNS TEXT AS $$
DECLARE
    result TEXT := '';
    test_row RECORD;
BEGIN
    result := result || E'\nLoad Test Results (' || iterations || ' iterations)\n';
    result := result || E'=====================================\n\n';
    
    FOR test_row IN SELECT * FROM run_load_test(iterations) LOOP
        result := result || 'Test: ' || test_row.test_name || E'\n';
        result := result || '  Average Duration: ' || test_row.avg_duration_ms || E' ms\n';
        result := result || '  Min Duration: ' || test_row.min_duration_ms || E' ms\n';
        result := result || '  Max Duration: ' || test_row.max_duration_ms || E' ms\n';
        result := result || '  Rows Processed: ' || test_row.total_rows || E'\n';
        result := result || '  Iterations: ' || test_row.iterations_completed || E'\n\n';
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Example usage with formatted output:
-- SELECT format_load_test_results(10);
