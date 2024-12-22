-- 创建两个不同的用户
CREATE USER user1 WITH PASSWORD '000000';
CREATE USER user2 WITH PASSWORD '000000';-- opengauss的密码得复杂一些

-- 创建测试表
CREATE TABLE test_table (
    id SERIAL PRIMARY KEY,
    name TEXT,
    age INT,
    salary INT
);

drop table test_table;
-- 插入测试数据
INSERT INTO test_table (name, age, salary) VALUES ('Alice', 25, 5000), ('Bob', 30, 6000);

-- 给 user1 授予表级 SELECT、INSERT、UPDATE 权限
GRANT SELECT, INSERT, UPDATE ON TABLE test_table TO user1;

-- 给 user2 授予表级 SELECT、DELETE 权限
GRANT SELECT, DELETE ON TABLE test_table TO user2;

-- 给所有用户默认拒绝权限（测试时可逐步开放）
REVOKE ALL ON TABLE test_table FROM PUBLIC;
-----------------------

---- select权限
\c test_db user1
-- 测试 SELECT 权限（应成功）
SELECT * FROM test_table;

\c test_db user2
-- 测试 SELECT 权限（应成功）
SELECT * FROM test_table;

\c test_db some_other_user
-- 测试 SELECT 权限（应失败）
SELECT * FROM test_table;

---- insert权限
\c test_db user1
-- 测试 INSERT 权限（应成功）
INSERT INTO test_table (name, age, salary) VALUES ('Charlie', 35, 7000);

\c test_db user2
-- 测试 INSERT 权限（应失败）
INSERT INTO test_table (name, age, salary) VALUES ('Dave', 40, 8000);

---- update权限
\c test_db user1
-- 测试 UPDATE 权限（应成功）
UPDATE test_table SET salary = 5500 WHERE name = 'Alice';

\c test_db user2
-- 测试 UPDATE 权限（应失败）
UPDATE test_table SET salary = 6500 WHERE name = 'Bob';

---- delete权限
\c test_db user2
-- 测试 DELETE 权限（应成功）
DELETE FROM test_table WHERE name = 'Charlie';

\c test_db user1
-- 测试 DELETE 权限（应失败）
DELETE FROM test_table WHERE name = 'Bob';

----------------
-- 设置列级权限
GRANT SELECT (name) ON TABLE test_table TO user1;
REVOKE SELECT (age, salary) ON TABLE test_table FROM user1;
GRANT SELECT (salary) ON TABLE test_table TO user2;
REVOKE SELECT (name, age) ON TABLE test_table FROM user2;

\c test_db user1
-- 测试读取特定列（应成功）
SELECT name FROM test_table;
-- 测试读取未授权列（应失败）
SELECT age, salary FROM test_table;

\c test_db user2
-- 测试读取特定列（应成功）
SELECT salary FROM test_table;
-- 测试读取未授权列（应失败）
SELECT name, age FROM test_table;

------------------------
-- 启用行级安全性
ALTER TABLE test_table ENABLE ROW LEVEL SECURITY;

-- 定义行级安全策略
revoke select on table test_table from user1;
revoke select on table test_table from user2;

CREATE POLICY user1_policy ON test_table
    FOR SELECT
    TO user1
    USING (salary < 6000); -- 仅允许读取 salary 小于 6000 的行
GRANT SELECT ON TABLE test_table TO user1;

CREATE POLICY user2_policy ON test_table
    FOR SELECT
    TO user2
    USING (age > 25); -- 仅允许读取 age 大于 25 的行
GRANT SELECT ON TABLE test_table TO user2;

\c test_db user1
-- 测试行级安全性（应只返回 salary < 6000 的行）
SELECT * FROM test_table;

\c test_db user2
-- 测试行级安全性（应只返回 age > 25 的行）
SELECT * FROM test_table;
---------------

---- 测试 REVOKE: 验证权限收回
-- 收回 user1 的 INSERT 权限
REVOKE INSERT ON TABLE test_table FROM user1;

-- 收回 user2 的 DELETE 权限
REVOKE DELETE ON TABLE test_table FROM user2;

\c test_db user1
SELECT CURRENT_USER; -- 检查当前用户
-- SELECT 和 UPDATE 应该仍然可以
SELECT * FROM test_table;
UPDATE test_table SET salary = 7500 WHERE name = 'Bob';
-- INSERT 应该失败
INSERT INTO test_table (name, age, salary) VALUES ('Grace', 27, 8000);

\c test_db user2
SELECT CURRENT_USER; -- 检查当前用户
-- SELECT 应该仍然可以
SELECT * FROM test_table;
-- DELETE 应该失败
DELETE FROM test_table WHERE name = 'Charlie';

-- 超级用户验证权限收回后的结果
\c test_db postgres
SELECT * FROM test_table;

-----------------------------------------------------------
---- 测试 GRANT: 恢复权限并验证
-- 恢复 user1 的 INSERT 权限
GRANT INSERT ON TABLE test_table TO user1;

-- 恢复 user2 的 DELETE 权限
GRANT DELETE ON TABLE test_table TO user2;

\c test_db user1
SELECT CURRENT_USER; -- 检查当前用户
-- INSERT 应该成功
INSERT INTO test_table (name, age, salary) VALUES ('Eve', 28, 6000);

\c test_db user2
SELECT CURRENT_USER; -- 检查当前用户
-- DELETE 应该成功
DELETE FROM test_table WHERE name = 'Eve';

-- 超级用户验证权限恢复后的结果
\c test_db postgres
SELECT * FROM test_table;
