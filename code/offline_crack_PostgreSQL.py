import csv
import pgpy
import time 

# 密钥字典：包含 9 个错误密钥和 1 个正确密钥
key_dict = [
    "WrongKey123",
    "IncorrectKey456",
    "FakeKey789",
    "InvalidKey000",
    "BadKey001",
    "FalseKey002",
    "MistakeKey003",
    "WrongPass004",
    "NotTheKey005",
    "Encrypt#123"  # 正确密钥
]

# 解密函数
def decrypt_pgp(data, key):
    try:
        encrypted_message = pgpy.PGPMessage.from_blob(data)
        decrypted_message = encrypted_message.decrypt(key)
        return decrypted_message.message
    except Exception as e:
        return None  # 返回 None 表示解密失败

# 加载加密数据
def load_encrypted_data(filepath):
    with open(filepath, 'r') as csvfile:
        reader = csv.reader(csvfile)
        headers = next(reader)  # 跳过表头
        encrypted_data = [row[1:] for row in reader]  # 跳过 id 列
    return encrypted_data

# 将十六进制字符串转为字节
def hex_to_bytes(hex_str):
    return bytes.fromhex(hex_str[2:])  


def main():
    encrypted_data = load_encrypted_data('/Users/ruiyuhan/Desktop/new_code/sensitive_table_PostgreSQL.csv')

    total_attempts = 0
    successful_attempts = 0
    records_count = len(encrypted_data)

    start_time = time.time()

    for record_idx, record in enumerate(encrypted_data, start=1):
        print(f"正在破解记录 {record_idx}/{records_count}...")
        record_success = False

        for key in key_dict:
            decrypted_values = []
            for encrypted_field in record:

                encrypted_field_bytes = hex_to_bytes(encrypted_field)
                decrypted_value = decrypt_pgp(encrypted_field_bytes, key)
                decrypted_values.append(decrypted_value)

            total_attempts += 1

            if all(decrypted_values): 
                print(f"  成功破解密钥: {key}, 解密结果: {decrypted_values}")
                successful_attempts += 1
                record_success = True
                break

        if not record_success:
            print("  所有密钥尝试失败，无法解密此记录。")

    end_time = time.time()

    total_time_ms = (end_time - start_time) * 1000

    print(f"\n总破解耗时: {total_time_ms:.2f} 毫秒")
    print(f"总尝试次数: {total_attempts}")
    print(f"成功破解次数: {successful_attempts}")

if __name__ == "__main__":
    main()
