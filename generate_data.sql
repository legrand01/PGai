-- Function to generate random text
CREATE OR REPLACE FUNCTION random_text(min_length INT, max_length INT) RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
    result TEXT := '';
    length INT;
BEGIN
    length := min_length + floor(random() * (max_length - min_length + 1))::INT;
    FOR i IN 1..length LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::INT, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to generate test data
CREATE OR REPLACE FUNCTION generate_test_data(
    num_users INT,
    num_products INT,
    num_orders INT,
    min_items_per_order INT DEFAULT 1,
    max_items_per_order INT DEFAULT 5
) RETURNS void AS $$
DECLARE
    user_id_var INT;
    product_id_var INT;
    order_id_var INT;
    num_items INT;
BEGIN
    -- Generate users
    FOR i IN 1..num_users LOOP
        INSERT INTO users (username, email, full_name, account_balance, preferences)
        VALUES (
            'user' || i,
            'user' || i || '@example.com',
            'Test User ' || i,
            random() * 1000,
            jsonb_build_object(
                'theme', (ARRAY['light', 'dark'])[floor(random() * 2 + 1)],
                'notifications', random() < 0.5,
                'language', (ARRAY['en', 'es', 'fr'])[floor(random() * 3 + 1)]
            )
        );
    END LOOP;

    -- Generate products
    FOR i IN 1..num_products LOOP
        INSERT INTO products (
            name,
            description,
            price,
            stock_quantity,
            category,
            tags,
            specifications
        )
        VALUES (
            'Product ' || i,
            'Description for product ' || i || '. ' || random_text(50, 200),
            (random() * 990 + 10)::DECIMAL(10,2),
            floor(random() * 1000)::INT,
            (ARRAY['Electronics', 'Clothing', 'Books', 'Home', 'Sports'])[floor(random() * 5 + 1)],
            ARRAY['tag' || floor(random() * 5 + 1), 'tag' || floor(random() * 5 + 1)],
            jsonb_build_object(
                'weight', random() * 10,
                'dimensions', jsonb_build_object(
                    'length', random() * 100,
                    'width', random() * 100,
                    'height', random() * 100
                )
            )
        );
    END LOOP;

    -- Generate orders and order items
    FOR i IN 1..num_orders LOOP
        -- Select random user
        SELECT user_id INTO user_id_var 
        FROM users 
        ORDER BY random() 
        LIMIT 1;

        -- Create order
        INSERT INTO orders (
            user_id,
            total_amount,
            status,
            shipping_address
        )
        VALUES (
            user_id_var,
            0, -- Will be updated after adding items
            (ARRAY['pending', 'processing', 'completed', 'cancelled'])[floor(random() * 4 + 1)],
            random_text(20, 100)
        )
        RETURNING order_id INTO order_id_var;

        -- Generate random number of items for this order
        num_items := min_items_per_order + floor(random() * (max_items_per_order - min_items_per_order + 1));

        -- Add items to order
        FOR j IN 1..num_items LOOP
            -- Select random product
            SELECT product_id INTO product_id_var 
            FROM products 
            ORDER BY random() 
            LIMIT 1;

            -- Add order item
            INSERT INTO order_items (
                order_id,
                product_id,
                quantity,
                price_at_time
            )
            VALUES (
                order_id_var,
                product_id_var,
                floor(random() * 5 + 1)::INT,
                (SELECT price FROM products WHERE product_id = product_id_var)
            );

            -- Add inventory transaction
            INSERT INTO inventory_transactions (
                product_id,
                transaction_type,
                quantity,
                reference_order_id,
                notes
            )
            VALUES (
                product_id_var,
                'ship',
                -1 * (floor(random() * 5 + 1)::INT),
                order_id_var,
                'Order ' || order_id_var
            );
        END LOOP;

        -- Update order total
        UPDATE orders 
        SET total_amount = (
            SELECT SUM(subtotal)
            FROM order_items
            WHERE order_id = order_id_var
        )
        WHERE order_id = order_id_var;

        -- Add reviews (50% chance per order)
        IF random() < 0.5 THEN
            INSERT INTO reviews (
                product_id,
                user_id,
                rating,
                review_text,
                helpful_votes
            )
            SELECT 
                product_id,
                user_id_var,
                floor(random() * 5 + 1)::INT,
                'Review for product. ' || random_text(20, 200),
                floor(random() * 100)::INT
            FROM order_items
            WHERE order_id = order_id_var;
        END IF;
    END LOOP;

    -- Refresh materialized view
    REFRESH MATERIALIZED VIEW product_stats;
END;
$$ LANGUAGE plpgsql;

-- Example usage:
-- Generate 1000 users, 500 products, and 2000 orders
-- SELECT generate_test_data(1000, 500, 2000, 1, 5);
