import psycopg2
import time
from subprocess import call

# 数据库连接信息
DB_CONFIG = {
    "dbname": "postgres",  # 数据库名称
    "user": "ruiyuhan",    # 数据库用户
    "password": "ruiyuhan111",  # 数据库密码
    "host": "localhost",   # 数据库主机
    "port": 5432           # PostgreSQL 默认端口
}

# 模拟数据库执行事务
def perform_transaction():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = False  # 禁用自动提交
        cur = conn.cursor()

        # 创建测试表
        cur.execute("""
        CREATE TABLE IF NOT EXISTS test_recovery (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL
        );
        """)

        # 插入测试数据
        cur.execute("INSERT INTO test_recovery (name) VALUES (%s);", ("Transaction Before Failure",))
        conn.commit()  # 提交事务
        print("事务提交成功：插入数据 'Transaction Before Failure'")

        cur.close()
        conn.close()
    except Exception as e:
        print(f"事务执行失败：{e}")

# 模拟数据库故障
def simulate_failure():
    print("模拟数据库故障：停止 PostgreSQL 服务...")
    # 使用 Homebrew 停止 PostgreSQL 服务
    call(["brew", "services", "stop", "postgresql"])  # 停止服务

    time.sleep(5)  # 模拟宕机时间
    print("重启 PostgreSQL 服务...")
    # 使用 Homebrew 启动 PostgreSQL 服务
    call(["brew", "services", "start", "postgresql"])  # 启动服务

# 验证数据恢复
def verify_recovery():
    try:
        time.sleep(10)  # 等待数据库完全启动

        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = True
        cur = conn.cursor()

        # 查询数据验证恢复结果
        cur.execute("SELECT * FROM test_recovery;")
        rows = cur.fetchall()
        if rows:
            print("数据库恢复成功，数据如下：")
            for row in rows:
                print(row)
        else:
            print("数据库恢复失败：未找到数据！")

        cur.close()
        conn.close()
    except Exception as e:
        print(f"验证失败：{e}")

if __name__ == "__main__":
    print("步骤 1：执行事务...")
    perform_transaction()

    print("步骤 2：模拟数据库故障...")
    simulate_failure()

    print("步骤 3：验证数据库恢复...")
    verify_recovery()
