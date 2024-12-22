-- 创建加密表 sensitive_data
DROP TABLE IF EXISTS sensitive_data;
CREATE TABLE sensitive_data (
    id SERIAL PRIMARY KEY,
    name text NOT NULL,
    email text NOT NULL,
    phone text NOT NULL,
    address text NOT NULL
);

-- 插入数据并加密
INSERT INTO sensitive_data (name, email, phone, address)
SELECT
    gs_encrypt_aes128('Name_' || i || '#', 'Encrypt#123'),
    gs_encrypt_aes128('Email_' || i || '@test.com', 'Encrypt#123'),
    gs_encrypt_aes128('12345_' || (i % 10) || '#', 'Encrypt#123'),
    gs_encrypt_aes128('Address_' || i || '!City_' || (i % 10), 'Encrypt#123')
FROM generate_series(1, 100) AS i;


-- 暴力破解
DO $$
DECLARE
    possible_key TEXT[] := ARRAY['WrongKey123', 'Encrypt#123', 'AnotherKey!']; -- 密钥字典；Encrypt#123是正确的密钥
    decrypted_name TEXT;
    current_key TEXT;
    encrypted_name text;
BEGIN
    FOR encrypted_name IN SELECT name FROM sensitive_data LOOP
        FOR current_key IN SELECT unnest(possible_key) LOOP
            BEGIN
                decrypted_name := gs_decrypt_aes128(encrypted_name, current_key);  -- 解密操作
                RAISE NOTICE '尝试密钥: %, 解密结果: %', current_key, COALESCE(decrypted_name, '解密失败');
            EXCEPTION
                WHEN others THEN
                    RAISE NOTICE '密钥 % 无法解密，错误信息: %', current_key, SQLERRM;
            END;
        END LOOP;
    END LOOP;
END $$;

---- 导出表格
\copy (SELECT id, name, email, phone, address FROM sensitive_data)
TO '/Users/ruiyuhan/Desktop/temp_code/sensitive_table_OpenGauss.csv'
DELIMITER ',' CSV HEADER;

-- 新密钥
DO $$
DECLARE
    new_key TEXT := 'NewKey#1234';
    old_key TEXT := 'Encrypt#1234';
    encrypted_name text;
    decrypted_name text;
BEGIN
    FOR encrypted_name IN SELECT name FROM sensitive_data LOOP
        BEGIN
            decrypted_name := gs_decrypt_aes128(encrypted_name, old_key::bytea);
            UPDATE sensitive_data
            SET name = gs_encrypt_aes128(decrypted_name, new_key::bytea)
            WHERE name = encrypted_name;
        EXCEPTION
            WHEN others THEN
                RAISE NOTICE '无法解密数据，错误信息: %', SQLERRM;
        END;
    END LOOP;

    FOR encrypted_name IN SELECT email FROM sensitive_data LOOP
        BEGIN
            decrypted_name := gs_decrypt_aes128(encrypted_name, old_key::bytea);
            UPDATE sensitive_data
            SET email = gs_encrypt_aes128(decrypted_name, new_key::bytea)
            WHERE email = encrypted_name;
        EXCEPTION
            WHEN others THEN
                RAISE NOTICE '无法解密数据，错误信息: %', SQLERRM;
        END;
    END LOOP;

    FOR encrypted_name IN SELECT phone FROM sensitive_data LOOP
        BEGIN
            decrypted_name := gs_decrypt_aes128(encrypted_name, old_key::bytea);
            UPDATE sensitive_data
            SET phone = gs_encrypt_aes128(decrypted_name, new_key::bytea)
            WHERE phone = encrypted_name;
        EXCEPTION
            WHEN others THEN
                RAISE NOTICE '无法解密数据，错误信息: %', SQLERRM;
        END;
    END LOOP;

    FOR encrypted_name IN SELECT address FROM sensitive_data LOOP
        BEGIN
            decrypted_name := gs_decrypt_aes128(encrypted_name, old_key::bytea);
            UPDATE sensitive_data
            SET address = gs_encrypt_aes128(decrypted_name, new_key::bytea)
            WHERE address = encrypted_name;
        EXCEPTION
            WHEN others THEN
                RAISE NOTICE '无法解密数据，错误信息: %', SQLERRM;
        END;
    END LOOP;
END $$;