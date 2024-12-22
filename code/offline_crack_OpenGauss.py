import csv
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import padding
import base64
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
def decrypt_aes128(encrypted_data, key):
    try:
        key_bytes = key.encode('utf-8')[:16]  
        key_bytes = key_bytes.ljust(16, b'\0')  

        encrypted_bytes = base64.b64decode(encrypted_data)

        if len(encrypted_bytes) % 16 != 0:
            print(f"警告: 密文的长度 ({len(encrypted_bytes)}) 不是 16 的倍数，进行填充处理。")
            padding_length = 16 - (len(encrypted_bytes) % 16)
            encrypted_bytes = encrypted_bytes + b'\0' * padding_length 

        cipher = Cipher(algorithms.AES(key_bytes), modes.ECB(), backend=default_backend())
        decryptor = cipher.decryptor()

        decrypted_bytes = decryptor.update(encrypted_bytes) + decryptor.finalize()
        try:
            unpadder = padding.PKCS7(128).unpadder()  # AES 是 128 位的
            unpadded_data = unpadder.update(decrypted_bytes) + unpadder.finalize()

            return unpadded_data.decode('utf-8')
        except Exception as e:
            print(f"填充错误: {str(e)}")
            return None
    
    except Exception as e:
        print(f"解密失败: {str(e)}")
        return None  # 解密失败则返回 None

# 加载加密数据
def load_encrypted_data(filepath):
    with open(filepath, 'r') as csvfile:
        reader = csv.reader(csvfile)
        headers = next(reader)  # 跳过表头
        encrypted_data = [row[1:] for row in reader]  # 跳过 id 列
    return encrypted_data

# 主函数
def main():
    encrypted_data = load_encrypted_data('/Users/ruiyuhan/Desktop/new_code/sensitive_table_OpenGauss.csv')

    total_attempts = 0
    successful_attempts = 0
    records_count = len(encrypted_data)

    start_time = time.time()

    for record_idx, record in enumerate(encrypted_data, start=1):
        print(f"正在破解记录 {record_idx}/{records_count}...")
        record_success = False

        for current_key in key_dict:
            decrypted_values = []
            for encrypted_field in record:
                decrypted_value = decrypt_aes128(encrypted_field, current_key)
                decrypted_values.append(decrypted_value)

            total_attempts += 1

            if all(decrypted_values):
                print(f"  成功破解密钥: {current_key}, 解密结果: {decrypted_values}")
                successful_attempts += 1
                record_success = True
                break 
        if not record_success:
            print(f"  所有密钥尝试失败，无法解密此记录。")


    end_time = time.time()

    total_time_ms = (end_time - start_time) * 1000

    print(f"\n总破解耗时: {total_time_ms:.2f} 毫秒")
    print(f"总尝试次数: {total_attempts}")
    print(f"成功破解次数: {successful_attempts}")

if __name__ == "__main__":
    main()