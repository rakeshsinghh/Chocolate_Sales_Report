SELECT * FROM calendar;

SELECT * FROM customers;

SELECT * FROM products;

SELECT * FROM sales;

SELECT * FROM stores;

-- 1.	Top Customer Identification:
-- Identify the top 3 customers based on the total profit they have generated.
-- Return their customer_id and total profit.

SELECT TOP 3 c.customer_id, 
ROUND(SUM(s.profit),2) Total_Profit 
FROM sales s
JOIN customers c
ON s.customer_id = c.customer_id
GROUP BY c.customer_id
ORDER BY Total_Profit DESC


-- 2.	High-Value Dark Chocolate Buyers:
-- Find "High-Value" customers 
-- (those who have spent a total of more than $500 across all orders) 
-- who have specifically purchased products with a cocoa_percent greater than 70%.

SELECT c.customer_id,
ROUND(SUM(s.revenue),2) AS Total_Revenue
FROM sales s
JOIN products p
ON s.product_id = p.product_id
JOIN customers c
ON c.customer_id = s.customer_id
WHERE p.cocoa_percent > 70 
GROUP BY c.customer_id
HAVING SUM(s.revenue) > 500;


-- 3.	Loyalty Member Preferences:
-- Compare loyalty members to non-loyalty members.
-- What is the single most popular product category (by total quantity sold) for each group?

WITH total_qty AS(
SELECT c.loyalty_member,
p.category,
SUM(s.quantity) AS Total_Qty,
ROW_NUMBER() OVER(PARTITION BY c.loyalty_member ORDER BY SUM(s.quantity) DESC) AS rnk
FROM sales s
JOIN customers c
ON s.customer_id = c.customer_id
JOIN products p
ON p.product_id = s.product_id
GROUP BY c.loyalty_member, p.category)

SELECT * FROM total_qty
WHERE rnk =	1;


-- 4.	Above-Average Store Performance:
-- Find all stores that have a higher average daily revenue than the overall average daily revenue calculated across all stores.
-- Return the store name and their daily average.

WITH daily_rev AS (
SELECT store_id,
order_date,
SUM(revenue) AS daily_revenue 
FROM sales
GROUP BY store_id, order_date
),

Store_performance AS(
SELECT store_id, 
AVG(daily_revenue) AS Avg_daily_revenue
FROM daily_rev
GROUP BY store_id)

SELECT s.store_name,
sp.Avg_daily_revenue 
FROM Store_performance sp
JOIN stores s ON
sp.store_id = s.store_id
WHERE sp.Avg_daily_revenue > (SELECT AVG(daily_revenue) FROM daily_rev);


-- 5.	Category Product Ranking:
-- Rank all products within their respective categories based on the total revenue they've generated.
-- Include the category, product name, total revenue, and rank.

SELECT 
p.category,
p.product_name,
ROUND(SUM(s.revenue),2) AS Total_Revenue,
ROW_NUMBER() OVER(PARTITION BY p.category ORDER BY SUM(s.revenue) DESC) AS 'rank'
FROM products p
JOIN sales s
ON p.product_id = s.product_id
GROUP BY p.category, p.product_name;


-- 6.	Cumulative Store Profit:
-- Calculate the cumulative running total of profit for each store chronologically by order_date.

WITH daily_profit AS (
SELECT 
st.store_id, 
st.store_name,
s.order_date,
ROUND(SUM(s.profit),2) AS Daily_profit
FROM stores st
JOIN sales s
ON st.store_id = s.store_id
GROUP BY st.store_id, st.store_name, s.order_date)

SELECT *,
SUM(Daily_profit) OVER(PARTITION BY store_id ORDER BY order_date) AS Cummalative_Profit
FROM daily_profit;


-- 7.	Month-Over-Month Revenue Growth:
-- Calculate the difference in sales revenue for each product between the current month and the previous month.

SELECT p.product_id,
p.product_name,
ROUND(SUM(s.revenue),2) AS Total_Revenue,
ROUND(LAG(SUM(s.revenue)) OVER(ORDER BY s.order_date),2) PM_Sales,
ROUND(SUM(s.revenue),2) - ROUND(LAG(SUM(s.revenue)) OVER(ORDER BY s.order_date),2) AS MoM
FROM sales s
JOIN products p
ON s.product_id = p.product_id
GROUP BY p.product_id, p.product_name, s.order_date;


-- 8.	Top Product by Country:
-- Find the single product that generated the highest total profit in each country.

WITH Country_Total AS (
SELECT st.country,
p.product_id,
p.product_name,
ROUND(SUM(s.revenue),2) AS Total_revenue,
ROW_NUMBER() OVER(PARTITION BY st.country ORDER BY SUM(s.revenue) DESC) AS rnk 
FROM sales s
JOIN stores st
ON s.store_id = st.store_id
JOIN products p
ON s.product_id = p.product_id
GROUP BY st.country, p.product_id, p.product_name)

SELECT country,
product_name,
Total_revenue
FROM Country_Total
WHERE rnk = 1;


-- 9.	7-Day Moving Average:
-- Calculate the 7-day moving average of total daily sales quantity across the entire business.

WITH Daily_total_sales AS (
SELECT order_date,
SUM(quantity) AS total_qty
FROM sales  
GROUP BY order_date)

SELECT *,
ROUND(AVG(total_qty) OVER(ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS moving_avg_7_day
FROM Daily_total_sales;


-- 10.	Store Revenue Contribution Percentage:
-- Determine what percentage of a city's total revenue comes from each individual store located in that city.

SELECT st.city,
st.store_id,
st.store_name,
ROUND(SUM(s.revenue),2) AS store_revenue,
ROUND(SUM(s.revenue)*100.0 / SUM(SUM(s.revenue)) OVER(PARTITION BY st.city),2) AS contri
FROM sales s
JOIN stores st
ON s.store_id = st.store_id
GROUP BY st.city, st.store_id, st.store_name;


-- 11.	Customer's First Purchase:
-- Find the very first product purchased by each customer and the date of that initial transaction.

WITH ranked_products AS (
SELECT s.customer_id,
p.product_name,
s.order_date,
ROW_NUMBER() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rnk
FROM sales s
JOIN products p
ON s.product_id = p.product_id )

SELECT customer_id,
product_name,
order_date AS First_Purchase_date
FROM ranked_products
WHERE rnk = 1;


-- 12.	Top 2 Stores per Country:
-- Find the top 2 performing stores (by total revenue) in each country, displaying their rank.

WITH Top_rev_stores AS (
SELECT st.country,
st.store_id,
st.store_name,
ROUND(SUM(s.revenue),2) AS Total_Revenue,
ROW_NUMBER() OVER(PARTITION BY st.country ORDER BY SUM(s.revenue) DESC) AS rnk 
FROM sales s
JOIN stores st
ON s.store_id = st.store_id 
GROUP BY st.country, st.store_id, st.store_name)

SELECT country,
store_name,
Total_Revenue,
rnk
FROM Top_rev_stores
WHERE rnk <= 2;


-- 13.	Days Between First and Second Order:
-- Calculate the number of days that elapsed between a customer's first purchase and their second purchase.
-- Return the customer_id and the days between.
-- Only include customers who have made at least two purchases.

WITH unique_orders AS (
SELECT DISTINCT customer_id,
order_date
FROM sales ),

purchase_rank AS (
SELECT customer_id,
order_date,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) AS Rnk 
FROM unique_orders )

SELECT f.customer_id,
f.order_date AS first_order_date,
s.order_date AS second_order_date,
DATEDIFF(DAY, f.order_date, s.order_date) AS days_difference
FROM purchase_rank f
JOIN purchase_rank s
ON f.customer_id = s.customer_id
WHERE f.Rnk = 1 AND s.Rnk = 2;


-- 14.	Hero Product per Store:
-- Identify the "Hero Product" for each store.
-- A Hero Product is the single product that contributed the most to the store's total profit.
-- Include the store name, product name, and the percentage of the store's total profit that the product accounts for.

WITH store_total AS (
SELECT st.store_id, 
st.store_name, 
p.product_name, 
ROUND(SUM(s.profit),2) AS Product_Profit, 
ROUND(SUM(s.profit) * 100.0 / SUM(SUM(s.profit)) OVER(PARTITION BY st.store_id),2) AS profit_percentage,
ROW_NUMBER() OVER(PARTITION BY st.store_id ORDER BY SUM(s.profit) DESC) AS rnk
FROM sales s
JOIN products p
ON s.product_id = p.product_id
JOIN stores st
ON s.store_id = st.store_id
GROUP BY st.store_id, st.store_name, p.product_name )

SELECT store_id,
store_name,
product_name AS hero_product,
profit_percentage
FROM store_total
WHERE rnk = 1;


-- 15.	Monthly Performance Report Procedure:
-- Create a stored procedure that takes a specific year and month as input parameters and 
-- returns the total sales revenue and total profit for that time period

CREATE PROCEDURE MonthlyPerformance
@Year INT,
@MONTH INT
AS BEGIN
	SELECT YEAR(order_date) AS Year,
	MONTH(order_date) AS Month,
	ROUND(SUM(revenue),2) AS Total_Revenue
	FROM sales 
	WHERE YEAR(order_date) = @Year AND MONTH(order_date) = @MONTH
	GROUP BY YEAR(order_date), MONTH(order_date)
	ORDER BY Year, Month
END;

MonthlyPerformance 2023,5;


-- 16.	Top N Products by Country Procedure:
-- Create a stored procedure that accepts a country name and a numeric limit (N)
-- to fetch the top N products by total revenue for that specific country.

CREATE PROCEDURE TopNProducts
@Country VARCHAR(20),
@TopN INT
AS BEGIN
	WITH top_products AS (
	SELECT st.country,
	p.product_name,
	ROUND(SUM(s.revenue),2) AS Total_Revenue,
	ROW_NUMBER() OVER(PARTITION BY st.country ORDER BY SUM(s.revenue) DESC) AS rnk
	FROM sales s
	JOIN stores st
	ON s.store_id = st.store_id
	JOIN products p
	ON s.product_id = p.product_id
	GROUP BY st.country, p.product_name)

	SELECT country,
	product_name,
	Total_Revenue,
	rnk
	FROM top_products
	WHERE country = @Country AND rnk <= @TopN
END;

TopNProducts 'USA',8;


SELECT DISTINCT country FROM stores;


-- 17.	Comprehensive Customer Summary Procedure: 
-- Create a stored procedure that takes a customer_id and returns a summary of their purchasing history:
-- total number of orders, lifetime amount spent, and their favorite brand (the brand they've bought the most items from).

CREATE PROCEDURE CustomerSummary
@EnterCustID VARCHAR(20)
AS BEGIN
	WITH BrandRanking AS (
	SELECT p.brand,
    COUNT(*) AS total_items,
    ROW_NUMBER() OVER(ORDER BY COUNT(*) DESC) AS rn
    FROM sales s
    JOIN products p
    ON s.product_id = p.product_id
    WHERE s.customer_id = @EnterCustID
    GROUP BY p.brand
 )

    SELECT s.customer_id,
    COUNT(DISTINCT s.order_id) AS total_orders,
    ROUND(SUM(s.revenue), 2) AS lifetime_amount_spent,
    ( SELECT brand
      FROM BrandRanking
      WHERE rn = 1 ) AS favorite_brand
    FROM sales s
    WHERE s.customer_id = @EnterCustID
    GROUP BY s.customer_id;

END;

CustomerSummary 'C027530';

SELECT DISTINCT customer_id FROM customers;


-- 18.	Top Customers by Store Type Procedure:
-- Create a stored procedure that takes a store_type and a numeric limit (N)
-- to fetch the top N customers based on total revenue generated within that specific store type.

CREATE PROCEDURE TopCustomers
@store_type VARCHAR(20),
@TopN INT
AS BEGIN
	WITH store_type_total AS (
	SELECT s.customer_id,
	st.store_type,
	ROUND(SUM(s.revenue),2) AS Total_Revenue,
	ROW_NUMBER() OVER(PARTITION BY st.store_type ORDER BY SUM(s.revenue) DESC) AS rnk
	FROM sales s
	JOIN stores st
	ON s.store_id = st.store_id
	GROUP BY s.customer_id, st.store_type )

	SELECT * FROM store_type_total
	WHERE store_type = @store_type AND rnk <= @TopN
END;

TopCustomers 'Airport', 5;


-- calendar	 = date			year			month				day					week			day_of_week
-- customers = customer_id	age				gender				loyalty_member		join_date
-- products	 = product_id	product_name	brand				category			cocoa_percent	weight_g
-- sales	 = order_id		order_date		product_id			store_id			customer_id		quantity	
--			   unit_price	discount		revenue	cost		profit
-- stores	 = store_id		store_name		city				country	store_type
