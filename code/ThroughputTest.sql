CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,         -- 自增主键，唯一标识每条记录
    account_name VARCHAR(100),
    balance DECIMAL(10, 2),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- 更新时间（用于 UPDATE 操作）
);

CREATE TABLE transaction_log (
    log_id SERIAL PRIMARY KEY,          -- 自增日志ID
    operation VARCHAR(10) NOT NULL,     -- 操作类型：INSERT、UPDATE、DELETE
    table_name VARCHAR(50),             -- 操作的表名
    affected_row_id INT,                -- 受影响的行ID
    old_balance DECIMAL(10, 2),         -- 旧值（用于 UPDATE/DELETE）
    new_balance DECIMAL(10, 2),         -- 新值（用于 INSERT/UPDATE）
    user_name TEXT DEFAULT current_user,-- 操作用户
    operation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- 操作时间
);

CREATE OR REPLACE FUNCTION log_account_transaction()
RETURNS TRIGGER AS $$
BEGIN
    -- 处理 INSERT 操作
    IF TG_OP = 'INSERT' THEN
        INSERT INTO transaction_log (operation, table_name, affected_row_id, new_balance, user_name)
        VALUES ('INSERT', TG_TABLE_NAME, NEW.id, NEW.balance, current_user);

    -- 处理 UPDATE 操作
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO transaction_log (operation, table_name, affected_row_id, old_balance, new_balance, user_name)
        VALUES ('UPDATE', TG_TABLE_NAME, NEW.id, OLD.balance, NEW.balance, current_user);

    -- 处理 DELETE 操作
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO transaction_log (operation, table_name, affected_row_id, old_balance, user_name)
        VALUES ('DELETE', TG_TABLE_NAME, OLD.id, OLD.balance, current_user);
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- INSERT 触发器
CREATE TRIGGER trigger_accounts_insert
AFTER INSERT ON accounts
FOR EACH ROW
EXECUTE FUNCTION log_account_transaction();

-- UPDATE 触发器
CREATE TRIGGER trigger_accounts_update
AFTER UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION log_account_transaction();

-- DELETE 触发器
CREATE TRIGGER trigger_accounts_delete
AFTER DELETE ON accounts
FOR EACH ROW
EXECUTE FUNCTION log_account_transaction();

-- 注意，OpenGauss的查询台中sql写法不同，得这样才不会报错
CREATE TRIGGER trigger_accounts_insert
AFTER INSERT ON accounts
FOR EACH ROW
EXECUTE PROCEDURE log_account_transaction();-- 另外两个也是一样

ALTER TABLE accounts DISABLE TRIGGER ALL;