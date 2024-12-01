-- Task 1
-- Goals: Find the top 10 countries with the most invoices, ordered by the number of invoices (descending) and country name (ascending).
-- Steps:
-- 1. Select the billing country and count the total number of invoices.
-- 2. Group by country to aggregate the total invoices for each.
-- 3. Sort by total invoices in descending order and by country name in ascending order for ties.
-- 4. Limit the results to the top 10 countries.
-- 5. Store the results in a temporary table for potential reuse.

CREATE TEMPORARY TABLE TopCountryByInvoice AS
	SELECT 
		"BillingCountry" AS country,
		COUNT("InvoiceId") AS total_invoice
	FROM 
		"Invoice"
	GROUP BY
		1
	ORDER BY
		2 DESC, 1
	LIMIT 10;

-- Task 2
-- Goals: Find the top 10 music genres by total sales in the database.
-- Steps:
-- 1. Create a CTE (TrackGenre) to associate each track with its genre using a JOIN between "Track" and "Genre."
-- 2. Calculate total sales per genre by summing UnitPrice * Quantity from "InvoiceLine."
-- 3. Join "InvoiceLine" with the CTE to connect sales data with genres.
-- 4. Group by genre to aggregate total sales for each genre.
-- 5. Sort the results by total sales in descending order.
-- 6. Limit the output to the top 10 genres.

WITH TrackGenre AS (
	SELECT
		"TrackId",
		g."Name" AS genre
	FROM
		"Track" t
		JOIN "Genre" g USING ("GenreId")
)

SELECT
	genre,
	SUM(il."UnitPrice" * il."Quantity") AS total_sales
FROM
	TrackGenre
	JOIN "InvoiceLine" il USING ("TrackId")
GROUP BY
	1
ORDER BY
	2 DESC
LIMIT 10;

-- Task 3
-- Goals: Identify the top 10 customers by total spending and show their full name, email, and total spending.
-- Steps:
-- 1. Combine the first and last names using CONCAT to create a full name.
-- 2. Select the email and calculate total spending as SUM("Total") from the "Invoice" table.
-- 3. Join "Customer" and "Invoice" tables to link customers with their spending data.
-- 4. Group by "CustomerId" to aggregate total spending for each customer.
-- 5. Sort by total spending in descending order.
-- 6. Limit the output to the top 10 customers.

SELECT
	CONCAT(c."FirstName", ' ', c."LastName") AS full_name,
	c."Email" AS email,
	SUM(i."Total") AS total_spending
FROM
	"Customer" c
	JOIN "Invoice" i USING ("CustomerId")
GROUP BY
	"CustomerId"
ORDER BY
	3 DESC
LIMIT 10;

-- Task 4
-- Goals: Identify the city with the most invoices for each country in the TopCountryByInvoice list.
-- Steps:
-- 1. Filter invoices to include only countries from the TopCountryByInvoice table.
-- 2. Group by country and city to calculate the total number of invoices per city.
-- 3. Use ROW_NUMBER to rank cities by the number of invoices for each country in descending order.
-- 4. Select the top-ranked city (rank = 1) for each country.

WITH CityInvoiceCounts AS (
    SELECT
        "BillingCountry" AS country,
        "BillingCity" AS city,
        COUNT("InvoiceId") AS total_invoices,
        ROW_NUMBER() OVER (PARTITION BY "BillingCountry" ORDER BY COUNT("InvoiceId") DESC) AS rank_num
    FROM 
        "Invoice"
    WHERE 
        "BillingCountry" IN (SELECT country FROM TopCountryByInvoice)
    GROUP BY 
        1, 2
)

SELECT
    country,
    city,
    total_invoices
FROM 
    CityInvoiceCounts
WHERE 
    rank_num = 1
ORDER BY 
    3 DESC, 1;
	
-- Task 5
-- Goals: Help the product team select 4 songs to add to the store by identifying the most popular genres in the UK based on the number of track purchases.
-- Steps:
-- 1. Create a CTE (PopularGenreUK) to calculate the total quantity of tracks sold for each genre in the UK.
-- 2. Rank genres by total sales in descending order using ROW_NUMBER.
-- 3. Use a VALUES clause to define the list of songs and their genres for consideration.
-- 4. Join the songs with the PopularGenreUK CTE to filter songs belonging to the most popular genres.
-- 5. Sort songs by genre popularity rank and select the top 4 using LIMIT.

WITH PopularGenreUK AS (
	SELECT
		g."Name" AS genre,
		SUM(il."Quantity") AS num_sold,
		ROW_NUMBER() OVER (ORDER BY SUM(il."Quantity") DESC) AS rank_num
	FROM
		"Invoice" i
		JOIN "InvoiceLine" il USING ("InvoiceId")
		JOIN "Track" t USING ("TrackId")
		JOIN "Genre" g USING ("GenreId")
	WHERE
		"BillingCountry" = 'United Kingdom'
	GROUP BY
		1
)

SELECT 
    song,
    s.genre
FROM (
    VALUES
        ('Lalaland', 'R&B/Soul'),
        ('Soul Sister', 'Pop'),
        ('Good to See You', 'Rock'),
        ('Nothing On You', 'Jazz'),
        ('Get Ya Before Sunrise', 'Reggae'),
        ('Before The Coffee Gets Cold', 'Hip Hop/Rap')
) AS s (song, genre)
	JOIN PopularGenreUK p USING(genre)
ORDER BY
    rank_num
LIMIT 4;

-- Task 6
-- Goals: Identify the top 10 most popular albums in the USA based on album units sold.
-- Steps:
-- 1. Join "Invoice", "InvoiceLine", "Track", and "Album" tables to link sales data to albums.
-- 2. Filter for invoices where the billing country is 'USA.'
-- 3. Group by album title to aggregate the total quantity of tracks sold for each album.
-- 4. Sort the results by the total units sold in descending order.
-- 5. Limit the output to the top 10 albums.

SELECT
	a."Title" AS album_name,
	SUM(il."Quantity") AS num_sold
FROM
	"Invoice" i
	JOIN "InvoiceLine" il USING ("InvoiceId")
	JOIN "Track" t USING ("TrackId")
	JOIN "Album" a USING ("AlbumId")
WHERE
	i."BillingCountry" = 'USA'
GROUP BY
	1
ORDER BY
	2 DESC
LIMIT 10;

-- Task 7
-- Goals: Aggregate purchase data by country, grouping countries with one customer as 'Others,' and calculate total customers, total sales, average sales per customer, and average order value.
-- Steps:
-- 1. Use a subquery to calculate the count of customers per country.
-- 2. Determine countries with one customer and label them as 'Others' in the main query.
-- 3. Join "Customer" and "Invoice" tables to aggregate sales data.
-- 4. Calculate metrics: total customers, total sales, average sales per customer, and average order value.
-- 5. Sort results by total sales in descending order.

WITH CountryCustomerCounts AS (
    SELECT
        "Country",
        COUNT("CustomerId") AS customer_count
    FROM
        "Customer"
    GROUP BY
        "Country"
)

SELECT
    CASE
        WHEN ccc.customer_count = 1 THEN 'Others'
        ELSE c."Country"
    END AS country,
    COUNT(DISTINCT c."CustomerId") AS total_customers,
    SUM(i."Total") AS total_sales,
    ROUND(SUM(i."Total") / COUNT(DISTINCT c."CustomerId"), 2) AS avg_sales_per_customer,
    ROUND(SUM(i."Total") / COUNT(i."InvoiceId"), 2) AS avg_order_value
FROM
    "Customer" c
    LEFT JOIN "Invoice" i USING ("CustomerId")
    JOIN CountryCustomerCounts ccc USING ("Country")
GROUP BY
	1
ORDER BY
    3 DESC;
	
-- Task 8
-- Goals: Analyze the genres with the highest total sales in the USA to identify low-performing genres for promotional strategies.
-- Steps:
-- 1. Join "Invoice," "InvoiceLine," "Track," and "Genre" tables to link invoices to genres.
-- 2. Filter the data to include only sales in the USA using the "BillingCountry" condition.
-- 3. Group the data by genre and calculate total sales as the sum of quantity multiplied by unit price for each genre.
-- 4. Order the results by total sales in ascending order and limit the output to the top 10 genres.

SELECT
	g."Name" AS genre,
	SUM(il."Quantity" * il."UnitPrice") AS total_sales
FROM
	"Invoice" i
	JOIN "InvoiceLine" il USING ("InvoiceId")
	JOIN "Track" t USING ("TrackId")
	JOIN "Genre" g USING ("GenreId")
WHERE
	i."BillingCountry" IN ('USA')
GROUP BY 
	1
ORDER BY 
	2 
LIMIT 10;

-- Task 9
-- Goals: Identify the top genre for each customer based on the highest spending.
-- Steps:
-- 1. Calculate total spending per genre for each customer as SUM(Quantity * UnitPrice).
-- 2. Use ROW_NUMBER to rank genres by spending for each customer in descending order.
-- 3. Select the top-ranked genre (rank_num = 1) for each customer.

WITH CustomerGenreSales AS (
    SELECT 
        CONCAT(c."FirstName", ' ', c."LastName") AS full_name,
        g."Name" AS genre,
        SUM(il."Quantity" * il."UnitPrice") AS total_sales
    FROM
        "Customer" c
        LEFT JOIN "Invoice" i USING ("CustomerId")
        JOIN "InvoiceLine" il USING ("InvoiceId")
        JOIN "Track" t USING ("TrackId")
        JOIN "Genre" g USING ("GenreId")
    GROUP BY 
        1, 2
),
CustomerGenreSalesRanked AS (
    SELECT 
        full_name,
        genre,
        total_sales,
        ROW_NUMBER() OVER (PARTITION BY full_name ORDER BY total_sales DESC) AS rank_num
    FROM 
        CustomerGenreSales
)

SELECT 
    full_name,
    genre,
    total_sales
FROM 
    CustomerGenreSalesRanked
WHERE 
    rank_num = 1
ORDER BY 
    3 DESC, 1;

-- Task 10
-- Goals: Identify the top 10 countries with the highest total spending by customers to guide marketing efforts.
-- Steps:
-- 1. Select the billing country and calculate total spending as SUM(i."Total").
-- 2. Join "Customer" and "Invoice" tables to link customers with their invoices.
-- 3. Group by billing country to aggregate total sales for each country.
-- 4. Sort by total sales in descending order and limit the results to the top 10 countries.

SELECT
	i."BillingCountry" AS Country,
	SUM(i."Total") AS total_sales
FROM 
	"Customer" c
	LEFT JOIN "Invoice" i USING ("CustomerId")
GROUP BY
	1
ORDER BY
	2 DESC
LIMIT 10;
