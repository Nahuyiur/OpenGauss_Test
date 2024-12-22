drop table accounts;
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    balance DECIMAL(10, 2) NOT NULL
);

INSERT INTO accounts (balance) VALUES (1000.00), (2000.00), (3000.00), (4000.00);


---- 原子性
BEGIN;
UPDATE accounts SET balance = balance - 500 WHERE account_id = 1;
UPDATE accounts SET balance = balance / 0 WHERE account_id = 2;
COMMIT; -- 因为事务中有错误，这里不会生效

ROLLBACK;
SELECT * FROM accounts;

---- 一致性
-- 添加约束，账户余额不能为负
ALTER TABLE accounts ADD CONSTRAINT balance_non_negative CHECK (balance >= 0);


BEGIN;
UPDATE accounts SET balance = balance - 3500 WHERE account_id = 3; -- 超出余额，违反约束
UPDATE accounts SET balance = balance + 3500 WHERE account_id = 4;
COMMIT; -- 因为违反约束，这里会失败
ROLLBACK;
SELECT * FROM accounts;

---- 隔离性
-- 设置事务隔离级别（在每个事务中单独设置）
SET TRANSACTION ISOLATION LEVEL <LEVEL>;

--read uncommitted
-- 事务 A：读取账户 1 的余额
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT balance FROM accounts WHERE account_id = 1;
-- 等待事务 B 执行
COMMIT;

-- 事务 B：更新账户 1 的余额
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
UPDATE accounts SET balance = balance - 500 WHERE account_id = 1;
-- 提交前切换到事务 A 执行
COMMIT;


-----
----read commited
-- 事务 A：读取账户 1 的余额
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE account_id = 1;
-- 等待事务 B 提交后再执行
SELECT balance FROM accounts WHERE account_id = 1;
COMMIT;

-- 事务 B：更新账户 1 的余额
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE accounts SET balance = balance - 500 WHERE account_id = 1;
COMMIT;
----
----repeatable read
-- 事务 A：读取账户 1 的余额
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE account_id = 1;
-- 等待事务 B 执行
SELECT balance FROM accounts WHERE account_id = 1;
COMMIT;

-- 事务 B：更新账户 1 的余额
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
UPDATE accounts SET balance = balance - 500 WHERE account_id = 1;
COMMIT;
----
---- serializable
-- 事务 A：读取账户 1 的余额
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT balance FROM accounts WHERE account_id = 1;
-- 尝试更新账户余额（与事务 B 冲突）
UPDATE accounts SET balance = balance + 200 WHERE account_id = 1;
COMMIT;

-- 事务 B：更新账户 1 的余额
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
UPDATE accounts SET balance = balance - 500 WHERE account_id = 1;
COMMIT;


---- 持久性
BEGIN;
UPDATE accounts SET balance = balance + 500 WHERE account_id = 4;
COMMIT;

-- 模拟数据库重启（在命令行执行）
-- sudo systemctl restart postgresql
SELECT * FROM accounts WHERE account_id = 4;