-- 创建主表 transactions，按 created_at 字段进行范围分区
CREATE TABLE transactions (
    id SERIAL,
    user_id INT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    PRIMARY KEY (id, created_at)      -- 主键包含分区键 created_at
) PARTITION BY RANGE (created_at);     -- 按时间范围进行分区

-- 创建分区表：2024 年第一季度
CREATE TABLE transactions_2024_q1 PARTITION OF transactions
FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

-- 创建分区表：2024 年第二季度
CREATE TABLE transactions_2024_q2 PARTITION OF transactions
FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

-- 创建分区表：2024 年第三季度
CREATE TABLE transactions_2024_q3 PARTITION OF transactions
FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');

-- 创建分区表：2024 年第四季度
CREATE TABLE transactions_2024_q4 PARTITION OF transactions
FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');

-- 插入模拟数据
INSERT INTO transactions (user_id, amount, created_at)
SELECT
    i % 1000,
    RANDOM() * 1000,
    TIMESTAMP '2024-01-01' +
    (RANDOM() * INTERVAL '365 days')
FROM generate_series(1, 1000000) AS i;


---- 分组统计查询
SELECT DATE_TRUNC('quarter', created_at) AS quarter, SUM(amount) AS total_amount
FROM transactions
GROUP BY DATE_TRUNC('quarter', created_at)
ORDER BY quarter;

---- 索引优化测试
-- 创建索引
drop index  idx_user_id;
CREATE INDEX idx_user_id ON transactions (user_id);

-- 测试索引查询
SELECT * FROM transactions WHERE user_id = 123;

-----------------------------
---- 动态添加新分区
-- 添加 2025 年第一季度分区
CREATE TABLE transactions_2025_q1 PARTITION OF transactions
FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');

-- 插入新的数据
INSERT INTO transactions (user_id, amount, created_at)
SELECT
    i % 1000,
    RANDOM() * 1000,
    TIMESTAMP '2025-01-01' + (RANDOM() * INTERVAL '90 days')
FROM generate_series(1, 100000) AS i;

-- 验证新分区查询能力
SELECT * FROM transactions WHERE created_at BETWEEN '2025-01-01' AND '2025-03-31';