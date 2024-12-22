DROP TABLE IF EXISTS sensitive_data;

CREATE TABLE sensitive_data (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    address TEXT NOT NULL
);

-- 插入测试数据，确保每列数据包含至少三种字符
INSERT INTO sensitive_data (name, email, phone, address)
SELECT
    'Name_' || i || '#',
    'Email_' || i || '@test.com',
    '12345_' || (i % 10) || '#',
    'Address_' || i || '!City_' || (i % 10)
FROM generate_series(1, 1000) AS i;


TRUNCATE TABLE sensitive_data;
INSERT INTO sensitive_data (name, email, phone, address)
SELECT
    'Name_' || i || '#',
    'Email_' || i || '@test.com',
    '12345_' || (i % 10) || '#',
    'Address_' || i || '!City_' || (i % 10)
FROM generate_series(1, 100000) AS i;

-- 启用 pgcrypto 扩展
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 使用 pgp_sym_encrypt 加密数据
UPDATE sensitive_data
    SET name = pgp_sym_encrypt(name, 'Encrypt#123'),
        email = pgp_sym_encrypt(email, 'Encrypt#123'),
        phone = pgp_sym_encrypt(phone, 'Encrypt#123'),
        address = pgp_sym_encrypt(address, 'Encrypt#123');


SELECT * FROM sensitive_data
WHERE pgp_sym_decrypt(name::bytea, 'Encrypt#123') LIKE 'Name_1%';


UPDATE sensitive_data
SET name = pgp_sym_encrypt('Updated_Name', 'Encrypt#123');




DROP TABLE IF EXISTS sensitive_data;
CREATE TABLE sensitive_data (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    address TEXT NOT NULL
);
------------------------------------------
TRUNCATE TABLE sensitive_data;
-- 插入未加密数据
DO $$
DECLARE
    i INT;
BEGIN
    RAISE NOTICE '开始插入未加密数据...';
    FOR i IN 1..100000 LOOP
        INSERT INTO sensitive_data (name, email, phone, address)
        VALUES (
            'Name_' || i || '#',
            'Email_' || i || '@test.com',
            '12345_' || (i % 10) || '#',
            'Address_' || i || '!City_' || (i % 10)
        );
    END LOOP;
    RAISE NOTICE '未加密数据插入完成';
END $$;

DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    updated_count INT;
BEGIN
    -- 开始计时
    RAISE NOTICE '开始更新未加密数据记录...';
    start_time := clock_timestamp(); -- 记录开始时间

    -- 更新操作
    UPDATE sensitive_data
    SET name = name || '_updated',
        email = email || '_updated',
        phone = phone || '_updated',
        address = address || '_updated';

    -- 获取受影响的记录数
    GET DIAGNOSTICS updated_count = ROW_COUNT;

    -- 结束计时
    end_time := clock_timestamp(); -- 记录结束时间

    -- 打印结果
    RAISE NOTICE '更新未加密数据完成，更新记录数：%, 总耗时：% 毫秒', updated_count, EXTRACT(MILLISECOND FROM end_time - start_time);
END $$;

DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    deleted_count INT;
BEGIN
    -- 开始计时
    RAISE NOTICE '开始删除未加密数据记录...';
    start_time := clock_timestamp(); -- 记录开始时间

    -- 删除操作
    DELETE FROM sensitive_data
    WHERE name LIKE 'Name_10%'; -- 匹配条件删除

    -- 获取受影响的记录数
    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- 结束计时
    end_time := clock_timestamp(); -- 记录结束时间

    -- 打印结果
    RAISE NOTICE '删除未加密数据完成，删除记录数：%, 总耗时：% 毫秒', deleted_count, EXTRACT(MILLISECOND FROM end_time - start_time);
END $$;
------------------------------------------
TRUNCATE TABLE sensitive_data;
-- 插入加密数据
DO $$
DECLARE
    i INT;
BEGIN
    RAISE NOTICE '开始插入加密数据...';
    FOR i IN 1..100000 LOOP
        INSERT INTO sensitive_data (name, email, phone, address)
        VALUES (
            pgp_sym_encrypt('Name_' || i || '#', 'Encrypt#123'),
            pgp_sym_encrypt('Email_' || i || '@test.com', 'Encrypt#123'),
            pgp_sym_encrypt('12345_' || (i % 10) || '#', 'Encrypt#123'),
            pgp_sym_encrypt('Address_' || i || '!City_' || (i % 10), 'Encrypt#123')
        );
    END LOOP;
    RAISE NOTICE '加密数据插入完成';
END $$;


DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
BEGIN
    RAISE NOTICE '开始更新加密数据...';
    start_time := clock_timestamp(); -- 记录开始时间

    UPDATE sensitive_data
    SET name = pgp_sym_encrypt(pgp_sym_decrypt(name::bytea, 'Encrypt#123') || '_updated', 'Encrypt#123'),
        email = pgp_sym_encrypt(pgp_sym_decrypt(email::bytea, 'Encrypt#123') || '_updated', 'Encrypt#123'),
        phone = pgp_sym_encrypt(pgp_sym_decrypt(phone::bytea, 'Encrypt#123') || '_updated', 'Encrypt#123'),
        address = pgp_sym_encrypt(pgp_sym_decrypt(address::bytea, 'Encrypt#123') || '_updated', 'Encrypt#123');

    end_time := clock_timestamp(); -- 记录结束时间

    RAISE NOTICE '更新加密数据完成，总耗时：% 毫秒', EXTRACT(MILLISECOND FROM end_time - start_time);
END $$;


DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    deleted_count INT;
BEGIN
    -- 开始计时
    RAISE NOTICE '开始删除加密数据记录...';
    start_time := clock_timestamp(); -- 记录开始时间

    -- 删除符合条件的数据
    DELETE FROM sensitive_data
    WHERE
        pgp_sym_decrypt(name::bytea, 'Encrypt#123') LIKE 'Name_10%'; -- 解密并匹配条件

    -- 获取受影响的记录数
    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- 结束计时
    end_time := clock_timestamp(); -- 记录结束时间

    -- 打印结果
    RAISE NOTICE '删除加密数据完成，删除记录数：%, 总耗时：% 毫秒', deleted_count, EXTRACT(MILLISECOND FROM end_time - start_time);
END $$;