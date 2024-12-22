CREATE INDEX idx_price ON books(price);

EXPLAIN ANALYZE
SELECT title, author, price
FROM books
WHERE price BETWEEN 50 AND 100;

CREATE INDEX idx_publish_date ON books(publish_date);

EXPLAIN ANALYZE
SELECT title, author, publish_date
FROM books
ORDER BY publish_date DESC
LIMIT 1000;