# PostgreSQL vs OpenGauss 数据库对比项目

## 🔍 项目简介

本项目通过一系列真实场景实验，对两大关系型数据库——**PostgreSQL 16** 和 **OpenGauss 3.0.0** 进行了深入对比，涵盖性能、安全性、扩展性、易用性、性能优化等多个维度。通过对两者在不同测试场景中的表现进行数据分析，为开发者和企业用户提供选择依据。

PostgreSQL 是全球最受欢迎的开源数据库之一，性能强大、功能丰富，拥有活跃的社区支持。OpenGauss 由华为主导开发，针对企业级场景优化，注重稳定性和安全性。本项目探讨它们在不同应用场景下的优劣势，揭示两者的适用性。

---

## ⚙️ 实验环境

### 硬件配置
- **处理器**：Apple M4 Pro 芯片，12 核 CPU，16 核 GPU
- **内存**：24GB 统一内存
- **存储**：512GB 固态硬盘

### 软件配置
- **操作系统**：macOS 15.1
- **PostgreSQL 版本**：PostgreSQL 16.6 (Postgres.app)，Apple clang 14.0.0 编译
- **OpenGauss 版本**：OpenGauss 3.0.0 (Docker 镜像)
- **开发语言**：Python、Java
- **测试工具**：pgbench、gs_prober、Scapy

---

## 📊 实验内容与结果

### **1️⃣ 性能对比**

#### 数据插入效率
通过插入 30 万条数据对插入效率进行对比，测量事务吞吐量、CPU/内存占用、磁盘 I/O 性能。
- **PostgreSQL** 的插入速度显著快于 OpenGauss，事务吞吐量更高。
- **OpenGauss** 表现稳定，资源使用更均匀。

| 数据库     | KB/t   | tps  | MB/s  | CPU 用户态 | 系统态 | 空闲 | 平均负载 |
| ---------- | ------ | ---- | ----- | ---------- | ------ | ---- | -------- |
| PostgreSQL | 108.34 | 3271 | 88.49 | 17%        | 5%     | 76%  | 2.27     |
| OpenGauss  | 189.55 | 998  | 95.69 | 12%        | 5%     | 83%  | 2.89     |

#### 查询效率
测试简单查询、复杂查询、分页查询的效率：
- PostgreSQL 在复杂查询（如排序、聚合）上表现更优。
- OpenGauss 在大偏移量分页查询中性能更稳定。

| 查询类型         | PostgreSQL | OpenGauss |
| ---------------- | ---------- | --------- |
| 简单查询         | 0.328ms    | 0.463ms   |
| 排序 + 分组查询  | 34.755ms   | 49.428ms  |
| 分页查询（10页） | 1.66s      | 0.15s     |

#### 吞吐量与延迟
测试高并发下的吞吐量和延迟：
- PostgreSQL 吞吐量高，延迟低，适合高性能场景。
- OpenGauss 资源调度稳定，适合负载均衡场景。

| 指标           | PostgreSQL | OpenGauss |
| -------------- | ---------- | --------- |
| 吞吐量（TPS）  | 29815      | 9107      |
| 平均延迟（ms） | 1.35       | 4.96      |

---

### **2️⃣ 安全性对比**

#### 权限管理
两者均支持表级、行级、列级权限管理，但行级权限控制上，OpenGauss 更为细粒度。

#### SQL 注入防护
两者均依赖参数化查询和安全函数防护 SQL 注入，对盲注和联合查询注入的防护效果相当。

#### 加密性能与安全性
测试加密数据的插入、查询、更新性能：
- **OpenGauss** 加密和解密效率高于 PostgreSQL，支持硬件加速。
- **离线破解抗性**：OpenGauss 对离线破解攻击的抗性更强。

| **测试项目**      | **PostgreSQL**    | **OpenGauss**   |
| ----------------- | ----------------- | --------------- |
| 加密性能（1000 条） | 加密耗时：2.5s    | 加密耗时：1.1s  |
| 查询加密数据      | 查询耗时：50ms    | 查询耗时：20ms  |
| 离线破解耗时      | 5 分钟             | 15 分钟         |

---

### **3️⃣ 扩展性对比**

#### 分区表性能
- PostgreSQL 在索引优化场景表现更优。
- OpenGauss 在动态分区扩展上效率更高，分区剪枝技术表现优秀。

#### 并发处理能力
- PostgreSQL 吞吐量更高，但资源使用波动较大。
- OpenGauss 在高并发场景下资源使用稳定，但 TPS 稍逊。

---

### **4️⃣ 易用性对比**

#### 安装与部署
- **PostgreSQL** 安装简单，适合多平台。
- **OpenGauss** 部署复杂，特别是在 macOS 上。

#### 运维工具支持
- **PostgreSQL** 提供 `pgbench` 基准测试工具，易于性能评估。
- **OpenGauss** 提供 `gs_prober` 性能监控工具，但缺乏基准测试能力。

---

### **5️⃣ 性能优化能力**

#### 配置调优
测试 `shared_buffers` 和 `work_mem` 参数对性能的影响：
- PostgreSQL 配置调优后性能提升显著。
- OpenGauss 在排序优化任务中提升潜力大，但整体略逊。

#### 查询计划分析
- PostgreSQL 查询计划透明，适合调优。
- OpenGauss 在并行查询计划信息中提供更多细节。

---
## 🛠️ 项目代码使用指南

### **运行环境准备**

#### 必备环境
- **JDK 8 或更高版本**：用于运行 Java 代码。
- **Python 3.x**：运行 Python 测试脚本。
- **Docker**：用于在容器中运行 OpenGauss（如果您使用的是 OpenGauss）。
- **PostgreSQL 客户端工具**：如 `psql`，用于连接 PostgreSQL 数据库。

#### 数据库设置
1. **PostgreSQL 设置**
   - 使用 `psql` 或 GUI 工具（如 DBeaver）创建测试数据库和用户。
   - 确保已安装 PostgreSQL JDBC 驱动程序（`postgresql-<version>.jar`）。
   - 配置 `pg_hba.conf` 文件，允许本地或远程连接。

2. **OpenGauss 设置**
   - 如果使用 Docker 镜像，请拉取 OpenGauss 3.0.0 镜像并启动容器：
     ```bash
     docker run -d -e GS_PASSWORD=your_password -p 15432:5432 opengauss-mirror
     ```

---

### **运行代码**

#### 1️⃣ Java 测试代码
项目中的 Java 代码用于测试数据库性能（如插入效率、查询效率、并发性能）。以下是运行步骤：

1. **添加依赖**
   - 在项目中添加 JDBC 驱动依赖：
     ```xml
     <!-- PostgreSQL JDBC Driver -->
     <dependency>
         <groupId>org.postgresql</groupId>
         <artifactId>postgresql</artifactId>
         <version>42.5.0</version>
     </dependency>
     
     <!-- OpenGauss JDBC Driver -->
     <dependency>
         <groupId>org.opengauss</groupId>
         <artifactId>opengauss-jdbc</artifactId>
         <version>3.0.0</version>
     </dependency>
     ```

2. **配置数据库连接**
   - 在代码中编辑数据库连接字符串：
     ```java
     // PostgreSQL 连接配置
     String url = "jdbc:postgresql://localhost:5432/testdb";
     String user = "your_username";
     String password = "your_password";

     // OpenGauss 连接配置
     String url = "jdbc:opengauss://localhost:15432/testdb";
     String user = "your_username";
     String password = "your_password";
     ```

3. **运行测试**
   - 执行测试类（如 `ThroughputTest.java`、`LatencyTest.java`），确保测试脚本能够正确连接到数据库。

---

#### 2️⃣ Python 测试代码
项目中的 Python 代码用于性能监控和可视化分析。以下是运行步骤：

1. **安装依赖**
   - 确保已安装必要的 Python 库：
     ```bash
     pip install psycopg2 pandas matplotlib
     ```

2. **配置数据库连接**
   - 在代码中修改数据库连接参数：
     ```python
     # PostgreSQL 连接配置
     conn = psycopg2.connect(
         host="localhost",
         port="5432",
         database="testdb",
         user="your_username",
         password="your_password"
     )

     # OpenGauss 连接配置（修改端口号为 OpenGauss 的默认端口）
     conn = psycopg2.connect(
         host="localhost",
         port="15432",
         database="testdb",
         user="your_username",
         password="your_password"
     )
     ```

3. **运行脚本**
   - 运行指定脚本，生成性能分析图表：
     ```bash
     python draw_latency_distribution.py
     ```
-------

## 🏆 对比总结

| **维度**       | **PostgreSQL**                                | **OpenGauss**                                 |
| -------------- | --------------------------------------------- | -------------------------------------------- |
| **性能**       | 插入效率高，查询速度快，吞吐量优               | 插入效率稍逊，分页查询性能优                  |
| **安全性**     | 加密性能略逊，SQL 注入防护依赖外部工具         | 加密性能优异，离线破解抗性更强                |
| **扩展性**     | 索引优化优，分区表性能强                      | 动态分区扩展更优，分区剪枝技术高效            |
| **易用性**     | 安装便捷，运维工具成熟                        | 部署复杂，日志功能丰富                        |
| **优化能力**   | 调优后性能显著提升，查询计划分析细致          | 查询计划信息透明，并行查询优化潜力大          |

---

## **目录结构说明**
### 硬件配置
- 处理器
- 内存
- 存储

### 软件配置
- 操作系统
- 数据库版本
- JVM
- 数据库驱动

### 衡量数据库好坏的标准

#### 性能
- 数据插入效率
- 查询效率
- 数据读取效率
- 吞吐量
- 延迟
- 索引效率

#### 可靠性
- 事务满足ACID特性
- 数据一致性
- 故障恢复能力

#### 安全性
- 权限管理
- SQL注入保护
- 数据加密解密能力
- 加密数据安全性
- 加密数据读写性能

#### 可拓展性
- 并发处理能力
- 分区表性能
- 动态分区拓展

#### 易用性
- 安装与部署难度
- 运维工具支持
- 日志功能

#### 性能优化能力
- 配置调优
- 查询计划分析

### 性能比较

#### 数据插入效率比较
- 表设计与数据生成
- 插入效率结果
- CPU与内存占用情况
- 总结

#### 查询效率
- 简单查询
- 略微复杂的查询
- 复杂查询
- 多表复合查询
- 总结

#### 数据读取效率
- 分页查询
- 复杂数据读取
- 总结

#### 吞吐量
- 并发插入、更新、删除操作测试
- TPS结果
- 总结

#### 延迟
- 高并发条件下的延迟测试
- 延迟分布结果
- 总结

#### 索引效率
- 条件过滤查询测试
- 排序查询测试
- 总结

### 可靠性

#### ACID特性
- 原子性
- 一致性
- 隔离性
- 持久性
- 总结

#### 故障恢复能力
- 事务数据恢复实验
- 总结

### 安全性

#### 权限
- 数据库连接权限测试
- 表级权限测试
- 列级权限测试
- 行级权限测试
- GRANT与REVOKE测试
- 总结

#### SQL注入保护
- 基础SQL注入
- 针对时间戳的注入
- JSON注入
- 盲注
- 联合查询注入
- 参数化查询保护
- 安全函数和检查机制
- 总结

#### 加密安全性与性能

##### 加密性能
- 数据加密效率测试
- 查询加密数据性能测试
- 更新加密数据性能测试
- 总结

##### 加密安全性
- 直接读取加密数据
- 暴力破解攻击
- 离线破解攻击
- 密钥管理和泄露测试
- 密钥更改与重新加密
- 总结

### 易用性

#### 安装与部署难度
- PostgreSQL
- OpenGauss
- 总结

#### 运维工具支持
- pgbench测试工具
- gs_prober监控工具
- 总结

#### 日志功能
- 日志类型
- 日志配置灵活性
- 日志管理能力
- 总结

### 可拓展性

#### 分区表性能
- 分组统计查询测试
- 索引优化测试
- 总结

#### 动态分区拓展
- 动态分区创建与数据插入测试
- 分区查询测试
- 总结

### 性能优化能力

#### 配置调优
- shared_buffers调整
- work_mem调整
- 总结

#### 查询计划分析
- PostgreSQL查询计划
- OpenGauss查询计划
- 总结

### 项目总结
- 性能对比
- 优势与劣势分析
- 使用场景适配性

### 项目心得


----
## 🌟 项目特色
- **真实场景实验**：涵盖插入、查询、安全性、扩展性、优化等多个场景。
- **详细数据分析**：从吞吐量到加密性能，提供详细的对比数据。
- **开放代码复现**：提供完整测试脚本，便于复现和扩展。

---

## 📬 联系我们
如果您对本项目有任何建议或反馈，请通过 GitHub Issues 联系我，感谢参与和讨论！
