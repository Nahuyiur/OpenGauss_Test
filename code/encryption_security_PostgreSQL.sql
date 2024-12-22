-- 创建加密表 sensitive_data
DROP TABLE IF EXISTS sensitive_data;
CREATE TABLE sensitive_data (
    id SERIAL PRIMARY KEY,
    name BYTEA NOT NULL,
    email BYTEA NOT NULL,
    phone BYTEA NOT NULL,
    address BYTEA NOT NULL
);

-- 插入数据并加密
INSERT INTO sensitive_data (name, email, phone, address)
SELECT
    pgp_sym_encrypt('Name_' || i || '#', 'Encrypt#123'),
    pgp_sym_encrypt('Email_' || i || '@test.com', 'Encrypt#123'),
    pgp_sym_encrypt('12345_' || (i % 10) || '#', 'Encrypt#123'),
    pgp_sym_encrypt('Address_' || i || '!City_' || (i % 10), 'Encrypt#123')
FROM generate_series(1, 100) AS i;

-- 启用 pgcrypto 扩展
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 暴力破解
DO $$
DECLARE
    possible_key TEXT[] := ARRAY['WrongKey123', 'Encrypt#123', 'AnotherKey!']; -- 密钥字典；Encrypt#123是正确的密钥
    decrypted_name TEXT;
    current_key TEXT;
    encrypted_name BYTEA;
BEGIN
    FOR encrypted_name IN SELECT name FROM sensitive_data LOOP
        FOR current_key IN SELECT unnest(possible_key) LOOP
            BEGIN
                decrypted_name := pgp_sym_decrypt(encrypted_name, current_key);
                RAISE NOTICE '尝试密钥: %, 解密结果: %', current_key, COALESCE(decrypted_name, '解密失败');
            EXCEPTION
                WHEN others THEN
                    RAISE NOTICE '密钥 % 无法解密，错误信息: %', current_key, SQLERRM;
            END;
        END LOOP;
    END LOOP;
END $$;

---- 导出表格
copy (SELECT id, name, email, phone, address FROM sensitive_data) TO '/Users/ruiyuhan/Desktop/temp_code/sensitive_table_PostgreSQL.csv' DELIMITER ',' CSV HEADER;


-- 使用新的密钥解密现有数据并重新加密
DO $$
DECLARE
    new_key TEXT := 'NewEncryptKey#456';  -- 新的加密密钥
    old_key TEXT := 'Encrypt#123';       -- 旧的加密密钥
    encrypted_name BYTEA;
    decrypted_name TEXT;
BEGIN
    FOR encrypted_name IN SELECT name FROM sensitive_data LOOP
        BEGIN
            decrypted_name := pgp_sym_decrypt(encrypted_name, old_key);
            UPDATE sensitive_data
            SET name = pgp_sym_encrypt(decrypted_name, new_key)
            WHERE name = encrypted_name;
        EXCEPTION
            WHEN others THEN
                RAISE NOTICE '无法解密数据，错误信息: %', SQLERRM;
        END;
    END LOOP;

    FOR encrypted_name IN SELECT email FROM sensitive_data LOOP
        BEGIN
            decrypted_name := pgp_sym_decrypt(encrypted_name, old_key);
            UPDATE sensitive_data
            SET email = pgp_sym_encrypt(decrypted_name, new_key)
            WHERE email = encrypted_name;
        EXCEPTION
            WHEN others THEN
                RAISE NOTICE '无法解密数据，错误信息: %', SQLERRM;
        END;
    END LOOP;

    FOR encrypted_name IN SELECT phone FROM sensitive_data LOOP
        BEGIN
            decrypted_name := pgp_sym_decrypt(encrypted_name, old_key);
            UPDATE sensitive_data
            SET phone = pgp_sym_encrypt(decrypted_name, new_key)
            WHERE phone = encrypted_name;
        EXCEPTION
            WHEN others THEN
                RAISE NOTICE '无法解密数据，错误信息: %', SQLERRM;
        END;
    END LOOP;

    FOR encrypted_name IN SELECT address FROM sensitive_data LOOP
        BEGIN
            decrypted_name := pgp_sym_decrypt(encrypted_name, old_key);
            UPDATE sensitive_data
            SET address = pgp_sym_encrypt(decrypted_name, new_key)
            WHERE address = encrypted_name;
        EXCEPTION
            WHEN others THEN
                RAISE NOTICE '无法解密数据，错误信息: %', SQLERRM;
        END;
    END LOOP;
END $$;