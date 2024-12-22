----simple query
--no condition
EXPLAIN ANALYZE
SELECT * FROM books LIMIT 1000;
--condition
EXPLAIN ANALYZE
SELECT * FROM books WHERE price < 50;
--only column
EXPLAIN ANALYZE
SELECT title, author FROM books;

----a little complex query
--order by
EXPLAIN ANALYZE
SELECT * FROM books ORDER BY price DESC LIMIT 1000;
--date range
EXPLAIN ANALYZE
SELECT * FROM books WHERE publish_date >= '2000-01-01' and publish_date<='2001-09-11';
--count and avg
EXPLAIN ANALYZE
SELECT COUNT(*) AS total_books, AVG(price) AS average_price FROM books;
--group by
EXPLAIN ANALYZE
SELECT author, COUNT(*) AS book_count
FROM books
GROUP BY author;

----complex query
--like
EXPLAIN ANALYZE
SELECT * FROM books WHERE title LIKE '%data%';
--multi condition
EXPLAIN ANALYZE
SELECT *
FROM books
WHERE price BETWEEN 20 AND 100
  AND publish_date > '2010-01-01';
--rank and subquery
EXPLAIN ANALYZE
SELECT *
FROM (
    SELECT *,
           RANK() OVER (ORDER BY publish_date DESC) AS rank
    FROM books
    WHERE price < 50
) AS ranked_books
WHERE rank <= 500;

DO $$
DECLARE
    counter INT := 0;
BEGIN
    WHILE counter < 500 LOOP
        RAISE NOTICE 'Executing iteration %', counter + 1;

        -- 执行目标查询
        EXECUTE '
            SELECT
                b.publish_date AS match_date,
                COUNT(*) AS total_books_sold,
                SUM(s.quantity_sold) AS total_quantity_sold,
                SUM(s.total_sale_amount) AS total_sales_amount
            FROM
                books b
            JOIN
                sales s
            ON
                b.publish_date = s.sale_date
            WHERE
                b.publish_date IS NOT NULL
                AND s.sale_date IS NOT NULL
                AND b.price > 10
                AND (s.total_sale_amount > 0 OR 1=1)
            GROUP BY
                b.publish_date
            HAVING
                SUM(s.quantity_sold) > 5
            ORDER BY
                total_sales_amount DESC
        ';

        counter := counter + 1;
    END LOOP;
END $$;