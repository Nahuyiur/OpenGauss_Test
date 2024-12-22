CREATE TABLE user_table (
    id SERIAL PRIMARY KEY,             -- 整数类型
    username VARCHAR(50),              -- 字符串类型
    password VARCHAR(50),              -- 字符串类型
    email TEXT,                        -- 长文本类型
    created_at TIMESTAMP DEFAULT NOW(),-- 时间戳类型
    is_active BOOLEAN DEFAULT TRUE,    -- 布尔类型
    preferences JSON                   -- JSON 类型
);

-- 插入测试数据
INSERT INTO user_table (username, password, email, preferences)
VALUES
('admin', 'admin123', 'admin@test.com', '{"theme": "dark", "language": "en"}'),
('user1', 'password1', 'user1@test.com', '{"theme": "light", "language": "fr"}'),
('user2', 'password2', 'user2@test.com', '{"theme": "dark", "language": "es"}');

-------------------------------
---- 基础SQL注入
-- 模拟正常登录
SELECT * FROM user_table WHERE username = 'admin' AND password = 'admin123';

-- 模拟基础注入攻击
SELECT * FROM user_table WHERE username = 'admin' OR '1'='1'; -- 总是返回 true
-------------------------------
---- 针对时间戳的注入
-- 模拟查询
SELECT * FROM user_table WHERE created_at = '2024-12-01';

-- 恶意注入
SELECT * FROM user_table WHERE created_at = '2024-12-01' OR '1'='1';
--------------------------------
---- JSON注入
-- 正常查询 JSON 数据
SELECT * FROM user_table WHERE preferences->>'theme' = 'dark';

-- JSON 注入
SELECT * FROM user_table WHERE preferences->>'theme' = 'dark' OR '1'='1';
----------------------------------
---- 盲注
-- 布尔盲注
SELECT * FROM user_table WHERE username = 'admin' AND LENGTH(password) > 5;

-- 时间盲注
SELECT * FROM user_table WHERE username = 'admin' AND pg_sleep(5);
----------------------------------
---- 联合查询注入
-- 恶意联合查询注入
SELECT id, username, password FROM user_table
WHERE username = 'user1'
UNION SELECT 1, table_name::text, column_name::text FROM information_schema.columns;
-----------------------------------
---- 安全函数和检查机制
-- 使用 PostgreSQL 的 QUOTE_LITERAL 转义
SELECT * FROM user_table WHERE username = QUOTE_LITERAL('user1'' OR ''1''=''1');