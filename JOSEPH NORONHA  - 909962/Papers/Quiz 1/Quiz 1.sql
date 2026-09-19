-- Joins

-- 1.  (Easy)  List every order with the customer's full name, store name, 
-- and the full name of the staff member who handled it.

SELECT 
       o.order_id,
       c.first_name + ' ' + c.last_name AS customer_name,  
       o.order_date,
       st.store_name,
       s.first_name + ' ' + s.last_name AS staff_name
FROM sales.orders o
INNER JOIN sales.customers c ON o.customer_id = c.customer_id
INNER JOIN sales.stores st ON st.store_id = o.store_id
INNER JOIN sales.staffs s ON s.staff_id = o.staff_id

-- 2.  (Easy)  Show each product with its brand name and category name. 
-- Include products even if they have no brand or category assigned
SELECT
    p.product_id,
    p.product_name,
    b.brand_name,
    c.category_name
FROM production.products p
LEFT JOIN production.brands b
    ON p.brand_id = b.brand_id
LEFT JOIN production.categories c
    ON p.category_id = c.category_id;

-- 3.  (Medium)  Find all customers who have never placed an order. Return their name, city, and email.
SELECT
    c.first_name + ' ' + c.last_name AS customer_name,  
    c.city,
    c.email
FROM sales.customers c 
LEFT JOIN sales.orders o
ON o.customer_id = c.customer_id
where o.customer_id = Null


-- GROUP BY

-- 4.  (Easy)  Calculate total revenue per store. Revenue = quantity * list_price * (1 - discount). 
--Sort from highest to lowest.
SELECT
    s.store_id,
    s.store_name,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
FROM sales.stores s
INNER JOIN sales.orders o
    ON s.store_id = o.store_id
INNER JOIN sales.order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY
    s.store_id,
    s.store_name
ORDER BY total_revenue DESC;

-- 5.  (Medium)  For each brand, show the number of products, 
-- the average list price, and the highest list price. Only include brands with more than 5 products.
SELECT
    b.brand_id,
    b.brand_name,
    COUNT(p.product_id) AS product_count,
    AVG(p.list_price) AS avg_price,
    MAX(p.list_price) AS highest_price
FROM production.brands b
INNER JOIN production.products p
    ON b.brand_id = p.brand_id
GROUP BY
    b.brand_id,
    b.brand_name
HAVING COUNT(p.product_id) > 5;

-- 6.  (Medium)  Show the number of orders and total revenue per month for the year 2017, 
-- ordered chronologically.
SELECT
    MONTH(o.order_date) AS order_month,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
FROM sales.orders o
INNER JOIN sales.order_items oi
    ON o.order_id = oi.order_id
WHERE YEAR(o.order_date) = 2017
GROUP BY MONTH(o.order_date)
ORDER BY order_month;

-- Subqueries

-- 7.  (Medium)  Find all products priced above the average list price of their own category.
-- Hint: Use a correlated subquery.
SELECT
    p.product_id,
    p.product_name,
    p.list_price,
    p.category_id
FROM production.products p
WHERE p.list_price > (
    SELECT AVG(p2.list_price)
    FROM production.products p2
    WHERE p2.category_id = p.category_id
);

-- 8.  (Medium)  List the customers who have placed more orders than the average number of orders per customer.
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(o.order_id) AS order_count
FROM sales.customers c
INNER JOIN sales.orders o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
HAVING COUNT(o.order_id) > (
    SELECT AVG(order_count * 1.0)
    FROM (
        SELECT COUNT(*) AS order_count
        FROM sales.orders
        GROUP BY customer_id
    ) AS customer_orders
);

-- CTEs
-- 9.  (Hard)  Using a CTE, calculate each customer's total spend, then return the top 10 customers with their spend and rank. Add a second CTE that labels each customer as "High" (above the overall average spend) or "Regular".
WITH customer_spend AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_spend
    FROM sales.customers c
    INNER JOIN sales.orders o
        ON c.customer_id = o.customer_id
    INNER JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 4
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
),
customer_labels AS (
    SELECT
        *,
        CASE
            WHEN total_spend > (
                SELECT AVG(total_spend)
                FROM customer_spend
            )
            THEN 'High'
            ELSE 'Regular'
        END AS customer_type
    FROM customer_spend
)
SELECT TOP 10
    customer_id,
    first_name,
    last_name,
    total_spend,
    customer_type,
    RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
FROM customer_labels
ORDER BY total_spend DESC;

-- 10.  (Hard)  Using CTEs, find the best-selling product (by quantity) in each category, 
-- and show how much of that product's stock is currently available across all stores.
-- Hint: Use ROW_NUMBER() or RANK() partitioned by category, then join to production.stocks.
WITH product_sales AS (
    SELECT
        p.category_id,
        p.product_id,
        p.product_name,
        SUM(oi.quantity) AS quantity_sold
    FROM production.products p
    INNER JOIN sales.order_items oi
        ON p.product_id = oi.product_id
    INNER JOIN sales.orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 4
    GROUP BY
        p.category_id,
        p.product_id,
        p.product_name
),
ranked_products AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY category_id
            ORDER BY quantity_sold DESC
        ) AS rn
    FROM product_sales
),
product_stock AS (
    SELECT
        product_id,
        SUM(quantity) AS available_stock
    FROM production.stocks
    GROUP BY product_id
)
SELECT
    c.category_name,
    rp.product_id,
    rp.product_name,
    rp.quantity_sold,
    COALESCE(ps.available_stock, 0) AS available_stock
FROM ranked_products rp
INNER JOIN production.categories c
    ON rp.category_id = c.category_id
LEFT JOIN product_stock ps
    ON rp.product_id = ps.product_id
WHERE rp.rn = 1
ORDER BY c.category_name;

-- Bonus Challenges

-- Rewrite Q8 using a CTE instead of a subquery and compare readability.
WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(*) AS order_count
    FROM sales.orders
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    co.order_count
FROM customer_orders co
INNER JOIN sales.customers c
    ON co.customer_id = c.customer_id
WHERE co.order_count > (
    SELECT AVG(order_count * 1.0)
    FROM customer_orders
)
ORDER BY co.order_count DESC;

-- For Q4, add a column showing each store's percentage share of total company revenue.
WITH store_revenue AS (
    SELECT
        s.store_id,
        s.store_name,
        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_revenue
    FROM sales.stores s
    INNER JOIN sales.orders o
        ON s.store_id = o.store_id
    INNER JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 4
    GROUP BY
        s.store_id,
        s.store_name
)
SELECT
    store_id,
    store_name,
    total_revenue,
    total_revenue * 100.0
        / SUM(total_revenue) OVER () AS revenue_percentage
FROM store_revenue
ORDER BY total_revenue DESC;