-- Complex queries for load testing PostgreSQL performance

-- 1. Full-text search with ranking
CREATE OR REPLACE FUNCTION search_products(search_term TEXT)
RETURNS TABLE (
    product_id INT,
    name VARCHAR(200),
    description TEXT,
    rank FLOAT4
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.product_id,
        p.name,
        p.description,
        ts_rank(p.search_vector, query) AS rank
    FROM 
        products p,
        plainto_tsquery('english', search_term) query
    WHERE 
        p.search_vector @@ query
    ORDER BY rank DESC;
END;
$$ LANGUAGE plpgsql;

-- 2. Complex aggregation with window functions
CREATE OR REPLACE FUNCTION analyze_user_spending()
RETURNS TABLE (
    user_id INT,
    username VARCHAR(50),
    total_spent DECIMAL(12,2),
    avg_order_value DECIMAL(12,2),
    percentile FLOAT,
    order_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH user_stats AS (
        SELECT 
            u.user_id,
            u.username,
            COUNT(o.order_id) as order_count,
            SUM(o.total_amount) as total_spent,
            AVG(o.total_amount) as avg_order_value,
            PERCENT_RANK() OVER (ORDER BY SUM(o.total_amount)) as percentile
        FROM users u
        LEFT JOIN orders o ON u.user_id = o.user_id
        GROUP BY u.user_id, u.username
    )
    SELECT 
        user_id,
        username,
        total_spent,
        avg_order_value,
        percentile::FLOAT,
        order_count
    FROM user_stats
    ORDER BY total_spent DESC;
END;
$$ LANGUAGE plpgsql;

-- 3. Product performance analysis
CREATE OR REPLACE FUNCTION analyze_product_performance(days_ago INT DEFAULT 30)
RETURNS TABLE (
    product_id INT,
    name VARCHAR(200),
    total_revenue DECIMAL(12,2),
    units_sold BIGINT,
    avg_rating DECIMAL(3,2),
    stock_status TEXT,
    reorder_suggestion BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH sales_data AS (
        SELECT 
            p.product_id,
            p.name,
            p.stock_quantity,
            COALESCE(SUM(oi.quantity * oi.price_at_time), 0) as revenue,
            COALESCE(SUM(oi.quantity), 0) as units_sold,
            COALESCE(AVG(r.rating), 0) as avg_rating
        FROM products p
        LEFT JOIN order_items oi ON p.product_id = oi.product_id
        LEFT JOIN orders o ON oi.order_id = o.order_id
        LEFT JOIN reviews r ON p.product_id = r.product_id
        WHERE o.created_at >= NOW() - (days_ago || ' days')::INTERVAL
        GROUP BY p.product_id, p.name, p.stock_quantity
    )
    SELECT 
        sd.product_id,
        sd.name,
        sd.revenue,
        sd.units_sold,
        ROUND(sd.avg_rating, 2)::DECIMAL(3,2),
        CASE 
            WHEN sd.stock_quantity = 0 THEN 'Out of Stock'
            WHEN sd.stock_quantity < 10 THEN 'Low Stock'
            WHEN sd.stock_quantity < 50 THEN 'Moderate Stock'
            ELSE 'Well Stocked'
        END as stock_status,
        (sd.stock_quantity < (sd.units_sold / days_ago) * 30) as reorder_suggestion
    FROM sales_data sd
    ORDER BY revenue DESC;
END;
$$ LANGUAGE plpgsql;

-- 4. Customer segmentation
CREATE OR REPLACE FUNCTION segment_customers()
RETURNS TABLE (
    segment TEXT,
    customer_count BIGINT,
    avg_order_value DECIMAL(12,2),
    total_revenue DECIMAL(12,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH customer_stats AS (
        SELECT 
            u.user_id,
            COUNT(o.order_id) as order_count,
            AVG(o.total_amount) as avg_order,
            SUM(o.total_amount) as total_spent,
            MAX(o.created_at) as last_order
        FROM users u
        LEFT JOIN orders o ON u.user_id = o.user_id
        GROUP BY u.user_id
    ),
    segments AS (
        SELECT 
            CASE 
                WHEN total_spent > 1000 AND order_count > 10 THEN 'VIP'
                WHEN total_spent > 500 OR order_count > 5 THEN 'Regular'
                WHEN last_order < NOW() - INTERVAL '6 months' THEN 'Inactive'
                ELSE 'New'
            END as segment,
            user_id,
            avg_order,
            total_spent
        FROM customer_stats
    )
    SELECT 
        segment,
        COUNT(*) as customer_count,
        ROUND(AVG(avg_order), 2) as avg_order_value,
        SUM(total_spent) as total_revenue
    FROM segments
    GROUP BY segment
    ORDER BY total_revenue DESC;
END;
$$ LANGUAGE plpgsql;

-- 5. Inventory analysis with moving averages
CREATE OR REPLACE FUNCTION analyze_inventory_trends(days_interval INT DEFAULT 7)
RETURNS TABLE (
    product_id INT,
    name VARCHAR(200),
    current_stock INT,
    daily_sales_avg DECIMAL(10,2),
    weekly_sales_avg DECIMAL(10,2),
    monthly_sales_avg DECIMAL(10,2),
    stock_coverage_days INT
) AS $$
BEGIN
    RETURN QUERY
    WITH daily_sales AS (
        SELECT 
            p.product_id,
            p.name,
            p.stock_quantity,
            DATE_TRUNC('day', o.created_at) as sale_date,
            COALESCE(SUM(oi.quantity), 0) as units_sold
        FROM products p
        LEFT JOIN order_items oi ON p.product_id = oi.product_id
        LEFT JOIN orders o ON oi.order_id = o.order_id
        WHERE o.created_at >= NOW() - INTERVAL '30 days'
        GROUP BY p.product_id, p.name, p.stock_quantity, DATE_TRUNC('day', o.created_at)
    ),
    moving_averages AS (
        SELECT 
            product_id,
            name,
            stock_quantity,
            AVG(units_sold) OVER (
                PARTITION BY product_id 
                ORDER BY sale_date 
                ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
            ) as daily_avg,
            AVG(units_sold) OVER (
                PARTITION BY product_id 
                ORDER BY sale_date 
                ROWS BETWEEN 7 PRECEDING AND CURRENT ROW
            ) as weekly_avg,
            AVG(units_sold) OVER (
                PARTITION BY product_id 
                ORDER BY sale_date 
                ROWS BETWEEN 30 PRECEDING AND CURRENT ROW
            ) as monthly_avg
        FROM daily_sales
    )
    SELECT DISTINCT
        product_id,
        name,
        stock_quantity as current_stock,
        ROUND(AVG(daily_avg), 2) as daily_sales_avg,
        ROUND(AVG(weekly_avg), 2) as weekly_sales_avg,
        ROUND(AVG(monthly_avg), 2) as monthly_sales_avg,
        CASE 
            WHEN AVG(daily_avg) > 0 
            THEN (stock_quantity / AVG(daily_avg))::INT 
            ELSE 999 
        END as stock_coverage_days
    FROM moving_averages
    GROUP BY product_id, name, stock_quantity
    ORDER BY stock_coverage_days;
END;
$$ LANGUAGE plpgsql;

-- Example load test queries:

-- Full-text search
-- SELECT * FROM search_products('wireless headphones');

-- User spending analysis
-- SELECT * FROM analyze_user_spending();

-- Product performance
-- SELECT * FROM analyze_product_performance(30);

-- Customer segmentation
-- SELECT * FROM segment_customers();

-- Inventory trends
-- SELECT * FROM analyze_inventory_trends(7);

-- Complex JOIN with aggregation
-- SELECT 
--     c.category,
--     COUNT(DISTINCT o.order_id) as total_orders,
--     COUNT(DISTINCT u.user_id) as unique_customers,
--     ROUND(AVG(oi.price_at_time), 2) as avg_price,
--     SUM(oi.quantity) as total_units_sold,
--     ROUND(AVG(r.rating), 2) as avg_rating
-- FROM products p
-- JOIN (SELECT DISTINCT category FROM products) c ON p.category = c.category
-- LEFT JOIN order_items oi ON p.product_id = oi.product_id
-- LEFT JOIN orders o ON oi.order_id = o.order_id
-- LEFT JOIN users u ON o.user_id = u.user_id
-- LEFT JOIN reviews r ON p.product_id = r.product_id
-- GROUP BY c.category
-- ORDER BY total_orders DESC;
