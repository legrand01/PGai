-- Create tables for load testing

-- Users table with various data types
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    account_balance DECIMAL(12,2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT true,
    preferences JSONB
);

-- Products table with text search capabilities
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INTEGER NOT NULL,
    category VARCHAR(50),
    tags TEXT[],
    specifications JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english', name), 'A') ||
        setweight(to_tsvector('english', COALESCE(description, '')), 'B')
    ) STORED
);

-- Orders table with foreign keys and constraints
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    total_amount DECIMAL(12,2) NOT NULL,
    status VARCHAR(20) CHECK (status IN ('pending', 'processing', 'completed', 'cancelled')),
    shipping_address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Order items for testing JOIN operations
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id),
    product_id INTEGER REFERENCES products(product_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price_at_time DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(12,2) GENERATED ALWAYS AS (quantity * price_at_time) STORED
);

-- Reviews table for testing aggregations and text search
CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(product_id),
    user_id INTEGER REFERENCES users(user_id),
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    helpful_votes INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('english', review_text)) STORED
);

-- Inventory transactions for testing high-frequency inserts
CREATE TABLE inventory_transactions (
    transaction_id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(product_id),
    transaction_type VARCHAR(20) CHECK (transaction_type IN ('receive', 'ship', 'adjust', 'return')),
    quantity INTEGER NOT NULL,
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reference_order_id INTEGER REFERENCES orders(order_id),
    notes TEXT
);

-- Create indexes for better query performance
CREATE INDEX idx_products_search ON products USING GIN(search_vector);
CREATE INDEX idx_reviews_search ON reviews USING GIN(search_vector);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_inventory_product_date ON inventory_transactions(product_id, transaction_date);

-- Create a function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for orders table
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create materialized view for product statistics
CREATE MATERIALIZED VIEW product_stats AS
SELECT 
    p.product_id,
    p.name,
    p.category,
    COUNT(DISTINCT o.order_id) as total_orders,
    COALESCE(SUM(oi.quantity), 0) as total_quantity_sold,
    COALESCE(AVG(r.rating), 0) as avg_rating,
    COUNT(DISTINCT r.review_id) as review_count
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN reviews r ON p.product_id = r.product_id
GROUP BY p.product_id, p.name, p.category;

-- Create index on materialized view
CREATE UNIQUE INDEX idx_product_stats_product_id ON product_stats(product_id);

COMMENT ON TABLE users IS 'User accounts for load testing';
COMMENT ON TABLE products IS 'Product catalog with text search capabilities';
COMMENT ON TABLE orders IS 'Customer orders with status tracking';
COMMENT ON TABLE order_items IS 'Individual items within orders';
COMMENT ON TABLE reviews IS 'Product reviews with text search';
COMMENT ON TABLE inventory_transactions IS 'Inventory movement tracking';
COMMENT ON MATERIALIZED VIEW product_stats IS 'Aggregated product statistics for reporting';
