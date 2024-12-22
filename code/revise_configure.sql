SHOW shared_buffers;--数据库缓存的内存
SHOW work_mem;-- 每个查询的内存限制
SHOW max_connections;-- 最大连接数


SHOW config_file;

SET shared_buffers TO '32MB';
SET work_mem TO '16MB';
SET max_connections TO 100;



CREATE TABLE test_data AS
SELECT
    id,
    random() AS value,
    md5(random()::text) AS text_column
FROM generate_series(1, 1000000) AS id;

ANALYZE test_data;

DO $$
DECLARE
    work_mem_values INTEGER[] := ARRAY[1024, 2048, 4096, 8192, 16384]; -- work_mem 值（单位：KB）
    query TEXT := 'SELECT * FROM test_data ORDER BY value LIMIT 10000;';
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    execution_time INTERVAL;
BEGIN
    FOR i IN 1..array_length(work_mem_values, 1) LOOP
        EXECUTE format('SET work_mem = %s;', work_mem_values[i]);
        start_time := clock_timestamp();
        EXECUTE query;
        end_time := clock_timestamp();
        execution_time := end_time - start_time;
        RAISE NOTICE 'work_mem: % MB | Execution Time: % 秒',
            work_mem_values[i] / 1024,
            EXTRACT(EPOCH FROM execution_time);
    END LOOP;
END $$;

