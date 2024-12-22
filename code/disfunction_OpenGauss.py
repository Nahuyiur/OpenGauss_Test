import psycopg2
import os
import time
from subprocess import Popen, call

# 数据库连接信息
# DB_CONFIG = {
#     "dbname": "ruiyuhan", 
#     "user": "ruiyuhan",  
#     "password": "ruiyuhan111", 
#     "host": "localhost", 
#     "port": 5432  
# }

DB_CONFIG = {
    "dbname": "postgres", 
    "user": "gaussdb",  
    "password": "Ruiyuhan123@",  
    "host": "localhost", 
    "port": 15432 
}

# 模拟数据库执行事务
def perform_transaction():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = False 
        cur = conn.cursor()

        cur.execute("""
        CREATE TABLE IF NOT EXISTS test_recovery (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL
        );
        """)

        cur.execute("INSERT INTO test_recovery (name) VALUES (%s);", ("Transaction Before Failure",))
        conn.commit()  
        print("事务提交成功：插入数据 'Transaction Before Failure'")

        cur.close()
        conn.close()
    except Exception as e:
        print(f"事务执行失败：{e}")

# 模拟数据库故障
def simulate_failure():
    print("模拟数据库故障：停止数据库服务...")
    call(["docker", "stop", "project3-opengauss"]) 

    time.sleep(5) 
    print("重启数据库服务...")
    call(["docker", "start", "project3-opengauss"])

# 验证数据恢复
def verify_recovery():
    try:
        time.sleep(10)

        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = True
        cur = conn.cursor()

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
