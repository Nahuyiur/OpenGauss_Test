DO $$
DECLARE
    i INT := 0;
    offset_value INT := 0;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    elapsed_time NUMERIC;
BEGIN
    WHILE i < 10 LOOP
        start_time := clock_timestamp();

        -- 执行分页查询（不将结果存储到变量）
        PERFORM *
        FROM (
            SELECT title
            FROM books
            ORDER BY title
            LIMIT 20000 OFFSET offset_value
        ) AS subquery;

        end_time := clock_timestamp();
        elapsed_time := ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
        RAISE NOTICE 'Page % with OFFSET % executed in % seconds', i + 1, offset_value, elapsed_time;
        offset_value := offset_value + 20000;
        i := i + 1;
    END LOOP;
END $$;

-- Page 1
EXPLAIN ANALYZE
SELECT title, author, publish_date, price
FROM books
WHERE price BETWEEN 50 AND 200
ORDER BY publish_date DESC, price ASC
LIMIT 10000 OFFSET 500000;

-- Page 2
EXPLAIN ANALYZE
SELECT title, author, publish_date, price
FROM books
WHERE price BETWEEN 50 AND 200
ORDER BY publish_date DESC, price ASC
LIMIT 10000 OFFSET 600000;

-- Page 3
EXPLAIN ANALYZE
SELECT title, author, publish_date, price
FROM books
WHERE price BETWEEN 50 AND 200
ORDER BY publish_date DESC, price ASC
LIMIT 10000 OFFSET 700000;