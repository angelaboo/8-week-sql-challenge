/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
-- 2. How many days has each customer visited the restaurant?
-- 3. What was the first item from the menu purchased by each customer?
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- 5. Which item was the most popular for each customer?
-- 6. Which item was purchased first by the customer after they became a member?
-- 7. Which item was purchased just before the customer became a member?
-- 8. What is the total items and amount spent for each member before they became a member?
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

/*
-- Example Query:
SELECT
  	product_id,
    product_name,
    price
FROM dannys_diner.menu
ORDER BY price DESC
LIMIT 5;
*/


-- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id,
       SUM(m.price) AS total_amount_spent
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;


-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, 
       COUNT(DISTINCT order_date) AS visit_count
FROM sales
GROUP BY customer_id;


--3. What was the first item from the menu purchased by each customer?
SELECT customer_id,
       product_name
FROM (
  SELECT s.customer_id,
         m.product_name,
         ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS row_num
  FROM sales s
  JOIN menu m
  ON s.product_id = m.product_id
) AS first_purchase
WHERE row_num = 1;


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT m.product_name,
       COUNT(s.product_id) AS total_purchase
FROM menu m
JOIN sales s
ON m.product_id = s.product_id
GROUP BY m.product_name
ORDER BY total_purchase DESC
LIMIT 1;


-- 5. Which item was the most popular for each customer?
 WITH customer_purchases AS (
   SELECT
       s.customer_id,
       m.product_name,
       COUNT(*) AS purchase_count,
       RANK() OVER (PARTITION BY customer_id ORDER BY COUNT(*) DESC) AS purchase_rank
   FROM sales s
   JOIN menu m
   ON s.product_id = m.product_id
   GROUP BY
       s.customer_id,
       m.product_name
   )
   SELECT
       customer_id,
       product_name,
       purchase_count
   FROM customer_purchases
   WHERE purchase_rank = 1;


-- 6. Which item was purchased first by the customer after they became a member?
WITH first_purchase_after_joining AS (
  SELECT
    sales.customer_id,
    menu.product_name,
    sales.order_date,
    ROW_NUMBER() OVER (PARTITION BY sales.customer_id ORDER BY sales.order_date) AS row_num
  FROM sales
  JOIN menu
  ON sales.product_id = menu.product_id
  JOIN members
  ON sales.customer_id = members.customer_id
  WHERE sales.order_date >= members.join_date
)

SELECT customer_id, product_name
FROM first_purchase_after_joining
WHERE row_num = 1;


-- 7. Which item was purchased just before the customer became a member?
WITH last_purchase_before_joining AS (
  SELECT
    sales.customer_id,
    menu.product_name,
    sales.order_date,
    ROW_NUMBER() OVER (PARTITION BY sales.customer_id ORDER BY sales.order_date DESC) AS row_num
  FROM sales
  JOIN menu
  ON sales.product_id = menu.product_id
  JOIN members
  ON sales.customer_id = members.customer_id
  WHERE sales.order_date < members.join_date
)

SELECT customer_id, product_name
FROM last_purchase_before_joining
WHERE row_num = 1;


-- 8. What is the total items and amount spent for each member before they became a member?
WITH purchases_before_joining AS (
  SELECT
    sales.customer_id,
    COUNT(sales.product_id) AS total_items,
    SUM(menu.price) AS total_spent
  FROM sales
  JOIN menu
  ON sales.product_id = menu.product_id
  JOIN members
  ON sales.customer_id = members.customer_id
  WHERE sales.order_date < members.join_date
  GROUP BY sales.customer_id
  ORDER BY sales.customer_id
)

SELECT customer_id, total_items, total_spent
FROM purchases_before_joining;


-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT s.customer_id,
       SUM(
         CASE
             WHEN m.product_name = 'sushi' THEN m.price * 20
             ELSE m.price * 10
         END
         ) AS total_points
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH customer_points AS (
    SELECT
        sales.customer_id,
        sales.order_date,
        menu.product_name,
        menu.price,
        members.join_date,
        CASE
            WHEN sales.order_date BETWEEN members.join_date AND (members.join_date + INTERVAL '6 days') THEN menu.price * 20
            WHEN menu.product_name = 'sushi' THEN menu.price * 20
            ELSE menu.price * 10
        END AS points
    FROM sales
    JOIN menu
    ON sales.product_id = menu.product_id
    JOIN members
    ON sales.customer_id = members.customer_id
    WHERE sales.order_date <= '2021-01-31'
)
SELECT
    customer_id,
    SUM(points) AS total_points
FROM customer_points
WHERE customer_id IN ('A', 'B')
GROUP BY customer_id
ORDER BY customer_id;


-- Bonus question #1: Join All the Things
SELECT
     sales.customer_id,
     sales.order_date,
     menu.product_name,
     menu.price,
     CASE
        WHEN members.join_date IS NULL THEN 'N'  -- Customer is not a member
        WHEN sales.order_date < members.join_date THEN 'N'  -- Order placed before joining
        ELSE 'Y'  -- Order placed on or after joining
     END AS member
FROM sales
JOIN menu
ON sales.product_id = menu.product_id
LEFT JOIN members
ON sales.customer_id = members.customer_id
ORDER BY
    sales.customer_id,
    sales.order_date,
    menu.product_name;


-- Bonus question #2: Rank All the Things
WITH customer_purchases AS (
    SELECT
        sales.customer_id,
        sales.order_date,
        menu.product_name,
        menu.price,
        CASE
            WHEN members.join_date IS NULL THEN 'N'  -- Customer is not a member
            WHEN sales.order_date < members.join_date THEN 'N'  -- Order placed before joining
            ELSE 'Y'  -- Order placed on or after joining
        END AS member
    FROM sales
    JOIN menu
    ON sales.product_id = menu.product_id
    LEFT JOIN members
    ON sales.customer_id = members.customer_id
)
SELECT
    customer_id,
    order_date,
    product_name,
    price,
    member,
    CASE
        WHEN member = 'Y' THEN
            RANK() OVER (PARTITION BY customer_id, member ORDER BY order_date)
        ELSE
            NULL
    END AS ranking
FROM customer_purchases
ORDER BY
    customer_id,
    order_date,
    product_name;