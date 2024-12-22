import random
import faker
import os

# 初始化 Faker 和随机数生成器
fake = faker.Faker()
num_records = 300000  

# 定义生成的 SQL 文件路径（存储在桌面上）
desktop_path = os.path.expanduser("~/Desktop")
output_file = os.path.join(desktop_path, "insert_books.sql")

# 打开文件写入 SQL 脚本
with open(output_file, 'w') as f:
    # 写入 SQL 脚本的开头部分
    f.write("INSERT INTO books (title, author, publish_date, price) VALUES\n")
    
    # 生成随机数据并写入到 SQL 脚本
    rows = []
    for _ in range(num_records):
        title = fake.sentence(nb_words=3).replace("'", "''")  # 随机书名，并处理单引号
        author = fake.name().replace("'", "''")  # 随机作者名，并处理单引号
        publish_date = fake.date_this_century()  # 随机出版日期
        price = round(random.uniform(10, 100), 2)  # 随机价格
        
        row = f"('{title}', '{author}', '{publish_date}', {price})"
        rows.append(row)
    
    # 将所有记录写入文件，逗号分隔，最后一条以分号结尾
    f.write(",\n".join(rows) + ";\n")

print(f"SQL 插入脚本已生成，文件保存在：{output_file}")