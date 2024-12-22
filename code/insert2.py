import random
import faker
import os

# 初始化 Faker 和随机数生成器
fake = faker.Faker()
num_records = 50000  # 生成的记录数量

# 定义生成的 SQL 文件路径（存储在桌面上）
desktop_path = os.path.expanduser("~/Desktop")
output_file = os.path.join(desktop_path, "insert_sales.sql")

# 打开文件写入 SQL 脚本
with open(output_file, 'w') as f:
    # 写入 SQL 脚本的开头部分
    f.write("INSERT INTO sales (book_title, sale_date, quantity_sold, total_sale_amount) VALUES\n")
    
    # 生成随机数据并写入到 SQL 脚本
    rows = []
    for _ in range(num_records):
        book_title = fake.sentence(nb_words=6).replace("'", "''")  # 随机书名，并处理单引号
        sale_date = fake.date_this_decade()  # 随机销售日期（最近 10 年）
        quantity_sold = random.randint(1, 20)  # 随机销售数量（1 到 20）
        total_sale_amount = round(quantity_sold * random.uniform(10, 100), 2)  # 销售总金额
        
        row = f"('{book_title}', '{sale_date}', {quantity_sold}, {total_sale_amount})"
        rows.append(row)
    
    # 将所有记录写入文件，逗号分隔，最后一条以分号结尾
    f.write(",\n".join(rows) + ";\n")

print(f"SQL 插入脚本已生成，文件保存在：{output_file}")