# 数据库project3

本次project比较的两个数据库是PostgreSQL16与OpenGauss 3.0.0版本（docker镜像）；在比较后问了同学，发现我这个结果差的有点大，==OpenGauss的表现不太理想，但是实验中的数据都是真实有效的==。

**硬件配置**

处理器：Apple M4 Pro芯片，12核心CPU，16核心GPU

内存：24GB统一内存

存储：512GB固态硬盘

**软件配置**

操作系统：macOS 15.1

数据库版本：PostgreSQL 16.6 (Postgres.app) on aarch64-apple-darwin21.6.0, compiled by Apple clang version 14.0.0 (clang-1400.0.29.102), 64-bit

JVM:OpenJDK 11.0.25

数据库驱动: PostgreSQL JDBC 42.7

## 衡量数据库好坏的标准

### 性能

数据插入效率：插入大量数据所需时间、每秒插入的事务量、cpu和内存占用情况

查询效率：简单select与复杂查询（join，聚合）相应速度

数据读取效率：大规模数据扫描、分页读取的速度

吞吐量：多用户并发操作下完成事务效率

延迟：在高负载条件下，响应时间分布

索引效率：对大规模数据添加索引对查询效率的提升

### 可靠性

事务满足ACID特性

在不同隔离等级下数据一致性

故障恢复能力：模拟数据库出现故障，检查数据是否能正常恢复

### 安全性

权限管理：对不同用户的权限正确生效

SQL注入保护

数据加密解密能力

加密数据安全性

加密数据读写性能

### 可拓展性

并发处理能力

分区表性能

动态分区拓展

### 易用性

安装与部署难度

运维工具支持

日志

### 性能优化能力

配置调优

查询计划分析

## 性能比较

### 数据插入效率比较

通过执行相同的插入任务，比较两个数据库的插入效率，包括==所需时间和cpu、内存占用情况。==

建立以下样式的表格，

```sql
CREATE TABLE books (
    title VARCHAR(255),
    author VARCHAR(255),
    publish_date DATE,
    price DECIMAL(10, 2)
);
```

用python生成30万条符合这个样式的数据记录(python代码见insert.py)，然后把它转换成sql脚本的形式：

```sql
explain analyse INSERT INTO books (title, author, publish_date, price) VALUES
('Notice staff.', 'Andrew Hoffman', '2008-03-19', 11.73),
('Whole democratic they.', 'Ronald Henry MD', '2023-09-16', 45.31),
('Candidate middle owner.', 'Robert Walker', '2017-03-14', 92.85),
('Find mouth.', 'Julie Coleman', '2002-07-05', 12.99),
...
```

分别在两个数据库内运行这个sql脚本，insert30万条数据，以下是运行的结果：

![image-20241217142505657](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217142505657.png)

![image-20241217142712358](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217142712358.png)

----

我们用**以下的指标来衡量cpu和内存占用情况：**

- **KB/t** ：每次磁盘I/O操作平均传输的数据量
- **tps**：每秒进行的磁盘I/O操作次数
- **MB/s**：每秒磁盘读写的数据量
- **us**：CPU在用户模式下花费的时间百分比
- **sy**：CPU在内核模式下花费的时间百分比
- **id**：CPU空闲的时间百分比
- **1分钟平均负载**

用**iostat命令**查看，每一秒刷新一次。

iostat命令得到的显示结果如下：

![image-20241217160927234](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217160927234.png)

我们控制变量比较，每次测量sql脚本运行期间的cpu和内存占用情况。（我们取和未运行sql脚本之前的情况做基准，取变化明显的时刻；这个比较比较粗略，但是我们会插入多次，取其中表现正常的比较）

单一时刻的比较：

| 数据库     | KB/t   | tps  | MB/s  | us   | sy   | id   | 1分钟平均负载 |
| :--------- | :----- | :--- | :---- | :--- | :--- | :--- | :------------ |
| PostgreSQL | 108.34 | 3271 | 88.49 | 17   | 5    | 76   | 2.27          |
| OpenGauss  | 189.55 | 998  | 95.69 | 12   | 5    | 83   | 2.89          |

整个事务过程：

![image-20241220103947718](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220103947718.png)

![image-20241220104008565](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220104008565.png)

#### 比较结果

**数据写入速度**

插入大量数据记录时，==postgresql的速度快于opengauss，每秒插入的事务量更大==。

**CPU 占用情况**

- **OpenGauss** 整体表现更平稳：用户态 (cpu_us) 和系统态 (cpu_sy) 占用较均匀，CPU 空闲时间 (cpu_id) 较高，说明资源利用更轻量。

- **PostgreSQL** 在部分观测点出现明显的 CPU 峰值，尤其在系统态占用方面波动较大，表现出更高的 CPU 压力。

**内存占用情况**

- **PostgreSQL** 在磁盘读写（KB/t、MB/s）和每秒 I/O 操作 (tps) 上表现出更高的峰值，说明 PostgreSQL 在这样的查询任务中通过资源消耗来提升吞吐量。

- **OpenGauss** 内存负载相对平稳，读写峰值较低，更适合资源受限的环境。

### 查询效率

通过执行相同的查询任务，比较两个数据库的查询效率，包括所需时间和cpu、内存占用情况。OpenGauss只反映total time，但是planning time均远小于execution time。(该部分代码见query_compare.sql)

#### 简单查询

```sql
----simple query
--no condition
EXPLAIN ANALYZE
SELECT * FROM books LIMIT 1000;
--condition
EXPLAIN ANALYZE
SELECT * FROM books WHERE price < 50;
--only column
EXPLAIN ANALYZE
SELECT title, author FROM books;
```

| 数据库     | 计划时间（查询1） | 执行时间（查询1） | 计划时间（查询2） | 执行时间（查询2） | 计划时间（查询3） | 执行时间（查询3） |
| ---------- | ----------------- | ----------------- | ----------------- | ----------------- | ----------------- | ----------------- |
| PostgreSQL | 0.051ms           | 0.328ms           | 0.045ms           | 44.551ms          | 0.047ms           | 34.755ms          |
| OpenGauss  | /                 | 0.463ms           | /                 | 40.880ms          | /                 | 49.428ms          |

简单查询下，==PostgreSQL查询速度略高于OpenGauss。==

#### 略微复杂的查询

```sql
----a little complex query
--order by
EXPLAIN ANALYZE
SELECT * FROM books ORDER BY price DESC LIMIT 1000;
--date range
EXPLAIN ANALYZE
SELECT * FROM books WHERE publish_date >= '2000-01-01' and publish_date<='2001-09-11';
--count and avg
EXPLAIN ANALYZE
SELECT COUNT(*) AS total_books, AVG(price) AS average_price FROM books;
--group by
EXPLAIN ANALYZE
SELECT author, COUNT(*) AS book_count
FROM books
GROUP BY author;
```

查询1:

![image-20241217171956938](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217171956938.png)

![image-20241217172035806](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217172035806.png)

查询2:

![image-20241217172101771](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217172101771.png)

![image-20241217172114727](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217172114727.png)

查询3:

![image-20241217172411058](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217172411058.png)

![image-20241217172425232](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217172425232.png)

查询4:

![image-20241217172440765](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217172440765.png)

![image-20241217172459796](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217172459796.png)

略微复杂的查询下，==PostgreSQL查询速度略高于OpenGauss；此外OpenGauss的排序内存开销、扫描开销高于PostgreSQL。==

#### 复杂查询

```sql
----complex query
--like
EXPLAIN ANALYZE
SELECT * FROM books WHERE title LIKE '%data%';
--multi condition
EXPLAIN ANALYZE
SELECT *
FROM books
WHERE price BETWEEN 20 AND 100
  AND publish_date > '2010-01-01';
--rank and subquery
EXPLAIN ANALYZE
SELECT *
FROM (
    SELECT *,
           RANK() OVER (ORDER BY publish_date DESC) AS rank
    FROM books
    WHERE price < 50
) AS ranked_books
WHERE rank <= 500;
```

查询1:

![image-20241217183850033](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217183850033.png)

![image-20241217183917827](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217183917827.png)

查询2:

![image-20241217183938670](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217183938670.png)

![image-20241217183954329](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217183954329.png)

查询3:

![image-20241217184012125](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217184012125.png)

![image-20241217184041013](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217184041013.png)

复杂查询下，==PostgreSQL查询速度高于OpenGauss，且OpenGauss的排序内存开销、扫描开销高于PostgreSQL==；相较于上面较为复杂的查询，**两者效率差异被放大了。**

#### 多表复合查询

为了多表查询，我们再次用之前的办法生成新的table sales(python代码见insert.py2)，sales表中插入50000条数据。

```sql
CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    book_title VARCHAR(255),
    sale_date DATE,
    quantity_sold INT,
    total_sale_amount DECIMAL(10,2)
);
```

采用的多表复合查询语句：

```sql
SELECT
                b.publish_date AS match_date,
                COUNT(*) AS total_books_sold,
                SUM(s.quantity_sold) AS total_quantity_sold,
                SUM(s.total_sale_amount) AS total_sales_amount
            FROM
                books b
            JOIN
                sales s
            ON
                b.publish_date = s.sale_date
            WHERE
                b.publish_date IS NOT NULL
                AND s.sale_date IS NOT NULL
                AND b.price > 10
                AND (s.total_sale_amount > 0 OR 1=1)
            GROUP BY
                b.publish_date
            HAVING
                SUM(s.quantity_sold) > 5
            ORDER BY
                total_sales_amount DESC
```

由于查询的时间太短，不能看到这个查询对cpu、内存的占用情况，我们可以用==循环控制执行多次查询==，这样能够观测到稳定的资源占用情况。

在以上的查询命令前再加上循环控制语句：

```sql
DO $$
DECLARE
    counter INT := 0;
BEGIN
    WHILE counter < 500 LOOP
        RAISE NOTICE 'Executing iteration %', counter + 1;

        -- 执行目标查询
        EXECUTE '
            --这里就是具体查询sql语句
        ';

        counter := counter + 1;
    END LOOP;
END $$;
```

500次查询用时见下图：

PostgreSQL

![image-20241217193415311](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217193415311.png)

OpenGauss

![image-20241217193330399](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217193330399.png)

在任务量较大的查询下，两个数据库的差异又被进一步放大；这里就能确定，在不做性能设置的情况下（默认情况），==PostgreSQL的查询速度快于OpenGauss。==

---------

整个事务过程中cpu、内存占用情况：

![image-20241220104037220](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220104037220.png)

![image-20241220104050519](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220104050519.png)

**CPU 占用情况**

- **OpenGauss** 整体 CPU 占用较低并且比较稳定：用户态 (cpu_us) 和系统态 (cpu_sy) 的占用率始终维持在较低水平，波动较小，CPU 空闲时间 (cpu_id) 长时间保持在 75%-80% 以上，说明 OpenGauss 在查询任务中对 CPU 资源的使用比较克制，负载轻量稳定。

- **PostgreSQL** 在部分观测点 CPU 占用较高并且波动明显：用户态 (cpu_us) 占用最高接近 30%，系统态 (**cpu_sy**) 的占用也有较大的上下浮动，尤其在多个观测点 CPU 空闲时间 (cpu_id) 降至 60% 左右，表明 PostgreSQL 在执行查询任务时对计算资源的需求较大，系统压力较高。

**内存占用情况**

- **PostgreSQL** 在磁盘传输和 I/O 操作方面有出更高的峰值：KB/t 和 MB/s 数据在几个观测点上升很显著，特别是在在事务吞吐量 (tps) 上表现出极高的峰值（超过 700），这说明了 PostgreSQL 在处理查询任务时通过大量资源消耗来实现更高的数据吞吐率和磁盘读写性能。

- **OpenGauss** 内存负载相对平稳：磁盘传输量 (KB/t) 和读写速率 (MB/s) 的波动较小，事务吞吐量 (tps) 表现中规中矩，没有什么明显的峰值，说明 OpenGauss 在执行查询任务时更加关注资源的稳定性，适合长时间负载均衡的场景。

#### 总结

**PostgreSQL** 在查询任务中表现出更高的资源消耗，但也实现了更快的查询速度，尤其在磁盘 I/O 和事务吞吐量上表现突出，适合对查询性能和吞吐量要求较高的场景。

**OpenGauss** 在查询任务中资源占用更低且表现稳定，虽然查询速度略逊于 PostgreSQL，但在长时间负载均衡或者是资源受限下表现可能会更稳定。

用我自己的感受来讲，无论是在插入还是在查询任务的比较中：**PostgreSQL** 优先追求激进的性能，代价就是需要消耗更多资源；而 **OpenGauss** 更注重资源利用的稳定性，性能偏保守。

这样的差异反映了两个数据库在设计理念上的差异，根据项目文档上所说的==“openGauss 被特别推荐用于**复杂数据密集型场景**==，如金融系统、电信业务和大型电商平台”，在这样的任务环境中，**系统的稳定性比极致性能更加重要。**

### 数据读取效率

实际上在查询效率比较中，也能部分反映数据读取的效率。因此我们采取一些更加能体现数据读取效率的任务来侧重比较这个方面的性能。可以评估数据库在**大规模数据扫描**、**数据检索** 和 **多字段排序**等场景下的数据读取性能。(该部分代码见data_reading.sql)

#### **分页查询**

这个实验侧重**随机访问性能**和**数据跳过效率**，随着offset增加性能差异会明显。

执行的分页查询代码如下：

```sql
DO $$
DECLARE
    i INT := 0;
    offset_value INT := 0;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    elapsed_time NUMERIC;
BEGIN
    WHILE i < 10 LOOP
        start_time := clock_timestamp();

        -- 执行分页查询（不将结果存储到变量）
        PERFORM *
        FROM (
            SELECT title
            FROM books
            ORDER BY title
            LIMIT 20000 OFFSET offset_value
        ) AS subquery;

        end_time := clock_timestamp();
        elapsed_time := ROUND(EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC, 2);
        RAISE NOTICE 'Page % with OFFSET % executed in % seconds', i + 1, offset_value, elapsed_time;
        offset_value := offset_value + 20000;
        i := i + 1;
    END LOOP;
END $$;
```

| 页码 | OFFSET | **PostgreSQL执行时间（s）** | OpenGauss执行时间（s） |
| ---- | ------ | --------------------------- | ---------------------- |
| 1    | 0      | 0.60                        | 0.07                   |
| 2    | 20000  | 0.81                        | 0.06                   |
| 3    | 40000  | 0.84                        | 0.07                   |
| 4    | 60000  | 1.62                        | 0.09                   |
| 5    | 80000  | 1.66                        | 0.13                   |
| 6    | 100000 | 0.94                        | 0.13                   |
| 7    | 120000 | 0.98                        | 0.15                   |
| 8    | 140000 | 1.00                        | 0.09                   |
| 9    | 160000 | 1.00                        | 0.09                   |
| 10   | 180000 | 1.01                        | 0.09                   |

~~讲实话这个结果让我大吃一惊，因为之前的实验看到的都是OpenGauss比较拉垮的性能表现。~~

**整体趋势**

- ==**openGauss** 在所有分页查询中表现出极低且稳定的执行时间==，耗时在 **0.06s ~ 0.15s** 之间，随着 OFFSET 增大，性能基本保持稳定。

- **PostgreSQL** 的执行时间随着 OFFSET 增加逐渐上升，从 **0.60s** 增长到 **1.66s**，表明 PostgreSQL 在处理OFFSET较大的分页查询时性能明显下降很多。

**性能差异**

- **openGauss**：能够快速跳过前面的数据行，性能稳定且不受 OFFSET 增大的影响。适合**大规模分页查询**，尤其在需要多次读取不同页码时性能表现更优。

- **PostgreSQL**：随着 OFFSET 增加，执行时间总体上呈明显增长，说明了PostgreSQL在处理大偏移量时效率较低。

**分析原因**

**PostgreSQL 的分页查询机制：**
	PostgreSQL 在执行 LIMIT ... OFFSET ... 查询时，仍然会从数据集的开头逐行扫描，只是跳过 OFFSET 指定的行数，但还是会经过之前的数据。分区表场景下，没有对分区页面进行精确统计。

**openGauss 的分页查询优化机制：**(opengauss,https://juejin.cn/post/7170135327342870536)

在分区表场景下，==openGauss 采用**分区剪枝技术**==，使 SQL 查询在执行过程中只访问**剪枝后的分区**，而不会扫描所有分区数据，避免不必要的 I/O 操作。

大致原理是基于均匀性假设，用以下公式估计分区页面数量：
$$
剪枝后分区页面数 = \frac{分区表总页面数 \times剪枝后分区数} { 总分区数}
$$

-------------

我们把books表格里面的内容复制两份，现在一共有900000条数据；这样子我们可以稳定测量cpu、内存占用情况。同样执行以上的代码，将“limit 20000”替换成“limit 60000”。

整个事务过程中cpu、内存占用情况：

![image-20241220104119700](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220104119700.png)

![image-20241220104140923](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220104140923.png)

资源占用情况和之前表现一样。

#### **复杂数据读取**

这个实验侧重**数据扫描效率**、**排序性能**和**资源调度能力**。

```sql
EXPLAIN ANALYZE
SELECT title, author, publish_date, price
FROM books
WHERE price BETWEEN 50 AND 200
ORDER BY publish_date DESC, price ASC
LIMIT 10000 OFFSET 500000; --OFFSET后的值分别取500000，600000，700000
```

PostgreSQL

![image-20241217210721983](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217210721983.png)

![image-20241217210744492](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217210744492.png)

![image-20241217210801868](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217210801868.png)

OpenGauss

![image-20241217210926309](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217210926309.png)

![image-20241217210940932](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217210940932.png)

![image-20241217210955983](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217210955983.png)

| 页码 | OFFSET | **PostgreSQL执行时间（ms）** | OpenGauss执行时间（ms） |
| ---- | ------ | ---------------------------- | ----------------------- |
| 1    | 500000 | 285.752                      | 401.708                 |
| 2    | 600000 | 291.447                      | 419.739                 |
| 3    | 700000 | 280.486                      | 410.594                 |

这个任务中，OpenGauss在排序过程中**对内存的消耗比PostgreSQL的消耗大了很多**，因此最后执行速度上PostgreSQL快很多。

注意到数据库执行排序操作时采用的方法存在一些差异：

**PostgreSQL**采用external merge：把数据切成小块，对每个小块做排序（一般是quick sort）；然后合并，合并一般在外部存储（因此是external）。数据量较大、内存不足时，比纯内存排序更适合。

**OpenGauss**就采用quick sort：内存内用分治法划分成两块然后递归排序。当内存足够的时候性能很好，但是在我们实验中这样较大的数据量下，就得借助临时存储，性能会急剧下降。这也是两个数据库执行时间差异的主要因素。

这个实验的结果和之前的查询结果类似，==处理综合数据读取任务的时候，**PostgreSQL**还是有一定优势。==

### 吞吐量

为了更好地测试数据库吞吐量，我们在数据库中建立和现实中类似的table，并用Java程序模拟多线程环境下并发插入。

建立accounts表，模拟交易操作；有一个主键 id，确保每个行数据都可以被唯一标识

```sql
CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,         -- 自增主键，唯一标识每条记录
    account_name VARCHAR(100),   
    balance DECIMAL(10, 2),    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- 更新时间（用于 UPDATE 操作）
);
```

建立transaction_log表，记录所有对 accounts 表的操作，

```sql
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
```

建立触发器函数 log_account_transaction，用于记录 INSERT、UPDATE 和 DELETE 操作，

```sql
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
```

建立三个触发器，

```sql
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

-- 注意，OpenGauss的查询台中sql写法不同，得这样才不会报错（把function改成procedure）
CREATE TRIGGER trigger_accounts_insert
AFTER INSERT ON accounts
FOR EACH ROW
EXECUTE PROCEDURE log_account_transaction();-- 另外两个也是一样
```

这部分代码见ThroughputTest.sql

------------------------

我们写了一个Java程序，模拟多线程环境下对数据库进行并发插入（INSERT）、更新（UPDATE）和删除（DELETE）操作，来测试数据库**在高并发情况下的处理能力和吞吐量**。（代码见DatabaseThroughputTest.java）

我们设置了50个线程，每个线程执行的事务数量为3000和10000个；插入、更新、删除操作均用随机值进行。

以下是执行相同数目事务的时间与TPS结果：

PostgreSQL

![image-20241217215819944](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217215819944.png)

![image-20241218205236840](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218205236840.png)

OpenGauss

![image-20241217220618007](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217220618007.png)

![image-20241218205023966](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218205023966.png)

查看 transaction_log 表，都存在150000+条记录，说明执行正常。

#### 结论

OpenGauss的高并发吞吐量比PostgreSQL差。然而这个结果似乎和OpenGauss社区文档中的结果存在差异，但是尊重实验结果，对出现这样结果进行原因分析：

- **OpenGauss** 的锁管理或事务调度机制可能在高并发场景下出现瓶颈，使得吞吐量下降；而PostgreSQL在这个任务中调度相对更成熟一些

- 我们的insert，update，delete操作都会写入数据和写入log，之前的实验表明OpenGauss的I/O操作的优化不如**PostgreSQL**，频繁的写入放大效应

- 触发器带来的额外开销，在高并发场景下成为瓶颈

  ---------------

  ![image-20241218085306217](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218085306217.png)

  以上是OpenGauss数据库移除trigger后的TPS，略有提升；说明还是==I/O操作上的性能差异是吞吐量低的主要因素。== 

  ### 延迟

延迟**侧重单个请求从发起到完成所需要的时间**，之前测的吞吐量侧重单位时间完成的事务量；延迟更加关注单个事务的体验感，会影响到数据库服务质量。

和测试吞吐量类似，我们用java程序**测试数据库在高并发条件下的事务延迟**，记录每个事务的响应时间（以毫秒为单位）并保存到文件中（代码见DatabaseLatencyTest.java），然后用python制图直观分析两个数据库的延迟比较（代码见draw_latency_distribution.py）。

以下是直方图结果：

![Figure_1](/Users/ruiyuhan/Desktop/Figure_1.png)

![Figure_2](/Users/ruiyuhan/Desktop/Figure_2.png)

**响应时间分布特征**

​	**PostgreSQL：**

- 大多数响应时间集中在 **2 ms 左右**，分布集中，峰值明显，说明PostgreSQL 的事务响应时间在高并发下稳定性很高，且极端情况下延迟较少。

​	**OpenGauss：**

- 响应时间主要分布在 **5 ms 到 10 ms** 区间，峰值低分布宽，有较大延迟时间；部分事务的响应时间较长，稳定性较差。

**总结**

- **PostgreSQL** 低延迟，稳定性好

- **OpenGauss** 平均响应时间较高，对响应时间要求相对较低的场景可能会适合一些

==这个延迟的结果和吞吐量相一致。==

### 索引效率

在这个实验中，我们比较在两个数据库中，**索引的添加**对查询效率的提升，特别是针对条件过滤和排序查询。

采取的books表现在有90万条数据，是30万组unique的数据复制得到。

#### 条件过滤查询

执行sql语句如下：

```sql
CREATE INDEX idx_price ON books(price);

EXPLAIN ANALYZE
SELECT title, author, price 
FROM books
WHERE price BETWEEN 50 AND 100;
```

PostgreSQL

添加索引前：

![image-20241218103024618](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218103024618.png)

添加索引后：

![image-20241218103058345](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218103058345.png)

OpenGauss

添加索引前：

![image-20241218103323258](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218103323258.png)

添加索引后：

![image-20241218103358654](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218103358654.png)

#### 排序查询

执行sql语句如下：

```sql
CREATE INDEX idx_publish_date ON books(publish_date);

EXPLAIN ANALYZE
SELECT title, author, publish_date 
FROM books
ORDER BY publish_date DESC
LIMIT 1000;
```

PostgreSQL

添加索引前：

![image-20241218103222967](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218103222967.png)

添加索引后：

![image-20241218103659140](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218103659140.png)

OpenGauss

添加索引前：

![image-20241218103421602](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218103421602.png)

添加索引后：

![image-20241218103446607](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218103446607.png)

-----------------

#### 总结

|                        | PosgreSQL | OpenGauss |
| ---------------------- | --------- | --------- |
| 条件过滤查询（索引前） | 120.713ms | 177.941ms |
| 条件过滤查询（索引后） | 101.749ms | 125.331ms |
| 排序查询（索引前）     | 72.495ms  | 167.544ms |
| 排序查询（索引后）     | 1.969ms   | 1.862ms   |

PostgreSQL 的初始性能略好，==而 OpenGauss 的索引优化带来了更大幅度的改进。==

~~这个也让我大吃一惊，每次OpenGauss数据库总能在莫名其妙的时候给人一点小小震撼。~~

因为在阅读社区文档的时候，OpenGauss明确承认了他在索引上可能存在的一些不足（Wu song，https://opengauss.org/zh/blogs/zhengwen2/OpenGauss%E7%B4%A2%E5%BC%95%E8%AF%A6%E8%A7%A3.html）：“openGauss 的索引支持仍在一些方面略有不足，例如不支持 BRIN 索引，缺少对 B-tree 索引的某些优化，以及缺乏布隆过滤器功能”。

那么查阅其他介绍，我猜测，针对索引优化更大的可能原因有：

- **OpenGauss**提供索引的自动维护和优化

- **OpenGauss** 在**分区表**的索引管理上进行了优化，尤其是**分区剪枝**和索引扫描优化；这个能在第二个任务中表现出来（limit 1000），而且在之前分页读取一部分中，我们也进行了实验验证；存在多级分区索引
- **OpenGauss**引入了**CB-Tree（Compressed B-Tree）索引**，这种索引在数据量较大、数据重复度较高的情况下能够明显减少索引占用的内存空间；这正好与我们的数据特点相契合（数据量大，重复率高）

## 可靠性

在这个部分我们就主要来测试ACID特性，数据一致性，故障恢复。

### ACID

我们创建下面的表格，插入数据来测试。（代码见ACID.sql）

```sql
drop table accounts;
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    balance DECIMAL(10, 2) NOT NULL
);
INSERT INTO accounts (balance) VALUES (1000.00), (2000.00), (3000.00), (4000.00);
```

#### 原子性

测试代码如下：

```sql
---- 原子性
BEGIN;
UPDATE accounts SET balance = balance - 500 WHERE account_id = 1;
UPDATE accounts SET balance = balance / 0 WHERE account_id = 2;
COMMIT; -- 因为事务中有错误，这里不会生效

ROLLBACK;
SELECT * FROM accounts;
```

![image-20241222131900207](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241222131900207.png)

因为事务中存在错误，整个事务不会执行，表中数据保持不变。

![image-20241222131915309](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241222131915309.png)

两个数据库的表现一致。

#### 一致性

测试代码如下：

```sql
---- 一致性
-- 添加约束，账户余额不能为负
ALTER TABLE accounts ADD CONSTRAINT balance_non_negative CHECK (balance >= 0);

BEGIN;
UPDATE accounts SET balance = balance - 3500 WHERE account_id = 3; -- 超出余额，违反约束
UPDATE accounts SET balance = balance + 3500 WHERE account_id = 4;
COMMIT; -- 因为违反约束，这里会失败
ROLLBACK;
SELECT * FROM accounts;
```

**![image-20241222132048461](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241222132048461.png)**

数据库数据会满足所有的完整性约束，每次操作后总是在合法状态。

表中数据仍不发生改变。

两个数据库的表现一致。

#### 隔离性

测试代码如下：

```sql
---- 隔离性
-- 设置事务隔离级别（在每个事务中单独设置）
SET TRANSACTION ISOLATION LEVEL <LEVEL>;-- 每次切换

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
```

下表表现了不同事务隔离等级下的实验结果：

| 隔离级别             | 实验结果                                                     |
| -------------------- | ------------------------------------------------------------ |
| **READ UNCOMMITTED** | 事务 A 第一次读取：1000，第二次读取：500（事务 B 更新但未提交） |
| **READ COMMITTED**   | 事务 A 第一次读取：1000，第二次读取：500（事务 B 提交后读取更新值） |
| **REPEATABLE READ**  | 事务 A 第一次读取：1000，第二次读取：1000（事务 B 提交后也读取事务开始时的值） |
| **SERIALIZABLE**     | 事务 A 第一次读取：1000，第二次更新失败（与事务 B 冲突）     |

两个数据库的表现一致。

#### 持久性

事务一旦提交，就会永久保存，即使出现故障事务结果也不会改变。

测试代码如下：

```sql
---- 持久性
BEGIN;
UPDATE accounts SET balance = balance + 500 WHERE account_id = 4;
COMMIT;
```

```cmd
#模拟数据库重启（在命令行执行）
sudo systemctl restart postgresql
```

```sql
SELECT * FROM accounts WHERE account_id = 4;
```

![image-20241222133747235](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241222133747235.png)

故障重新启动数据库，发现更改被保存下来。

两个数据库表现一致。

#### 总结

==ACID特性两个数据库肯定都得满足，否则会出现重大可靠性问题。==

### 故障恢复能力

我们写了python程序来验证，总体有以下几个步骤：

- **执行事务**：向数据库插入一条测试数据，并提交事务，确保事务的结果被写入数据库。
- **模拟故障**：通过停止数据库服务模拟系统崩溃的场景，随后重启数据库服务。
- **验证恢复**：重新连接数据库，检查提交的事务数据是否仍然存在，从而验证数据库的恢复能力。

代码见disfunction_PostgreSQL.py与disfunction_OpoenGauss.py.

PostgreSQL

![image-20241222135425080](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241222135425080.png)

OpenGauss

![image-20241222134705060](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241222134705060.png)

实验结果表明，PostgreSQL 和 OpenGauss ==都能够在服务崩溃后成功恢复已提交的事务数据==。重启后数据完整无误，说明它们在故障恢复方面表现可靠，可以很好地保障数据安全和一致性。

## 安全性

### 权限

我们检测了数据库操作中，常见的权限操作以及设计了可能会出现的问题。（本部分代码见privilege.sql）

#### 基础设置

```sql
-- 创建两个不同的用户
CREATE USER user1 WITH PASSWORD '000000';
CREATE USER user2 WITH PASSWORD '000000';

-- 创建测试表
CREATE TABLE test_table (
    id SERIAL PRIMARY KEY,
    name TEXT,
    age INT,
    salary INT
);

-- 插入测试数据
INSERT INTO test_table (name, age, salary) VALUES ('Alice', 25, 5000), ('Bob', 30, 6000);

-- 给 user1 授予表级 SELECT、INSERT、UPDATE 权限
GRANT SELECT, INSERT, UPDATE ON TABLE test_table TO user1;

-- 给 user2 授予表级 SELECT、DELETE 权限
GRANT SELECT, DELETE ON TABLE test_table TO user2;

-- 给所有用户默认拒绝权限（测试时可逐步开放）
REVOKE ALL ON TABLE test_table FROM PUBLIC;
```

#### 数据库连接权限测试

```cmd
# 这里的test_db切换成两个数据库 opengauss改5432为15432
# 测试 user1 是否能连接
psql -h localhost -p 5432 -U user1 -d test_db

# 测试 user2 是否能连接
psql -h localhost -p 5432 -U user2 -d test_db

# 测试未授权用户是否能连接（应拒绝）
psql -h localhost -p 5432 -U some_other_user -d test_db
```

user1，user2均能正常连接；未授权用户无法连接。

![image-20241218180603759](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218180603759.png)

![image-20241218180810343](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218180810343.png)

#### 表级权限测试

```sql
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
```

两个数据库表现一样，并且和预期一样；在没有权限时都会报错。

![image-20241218194529072](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218194529072.png)

#### 列级权限测试

```sql
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
```

PostgreSQL和OpenGauss在预测执行失败的却都能正常执行：

<img src="/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218195541351.png" alt="image-20241218195541351" style="zoom:50%;" />

<img src="/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218195601044.png" alt="image-20241218195601044" style="zoom:50%;" />

原因：它们都是表级权限控制，如果用户对表有整体的select权限，revoke不会剥夺读取列的权限

可以通过创建视图并赋予用户对视图的权限：

```sql
-- 创建仅包含 name 列的视图
CREATE VIEW test_table_user1_view AS SELECT name FROM test_table;
GRANT SELECT ON test_table_user1_view TO user1;

-- 撤销对原表的直接访问权限
REVOKE ALL ON test_table FROM user1;-- 这与本实验目的没有直接关系，简单提及
```

#### 行级权限测试

```sql
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
```

PostgreSQL和OpenGauss的行级安全策略都能正常实现，user1与user2只能查询到允许读取的行：

![image-20241218201946539](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218201946539.png)



![image-20241218202026001](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218202026001.png)

#### grand和revoke测试

```sql
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
```

PostgreSQL和OpenGauss在grand和revoke测试中表现均和预期一致：

revoke：

![image-20241218202541124](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218202541124.png)

![image-20241218202512013](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218202512013.png)

![image-20241218202657415](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218202657415.png)

grant：

![image-20241218202855436](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218202855436.png)

![image-20241218202919449](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218202919449.png)

![image-20241218202935302](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218202935302.png)

#### 总结

PostgreSQL和OpenGauss在权限上表现一致，很可靠。grant和revoke权限分配正常，可以使用行级安全性策略。

### SQL注入保护

SQL注入是在输入字段中插入专用的 SQL 语句，攻击者可以执行命令来攻击数据库。

漏洞的核心是，本应为特定类型的数据保留的 SQL 查询字段，**却传递了意外的信息（例如命令），然后这个命令允许时越过了预期的范围，造成恶意破坏。**

这个部分的实验设置了不同场景测试（例如简单注入、联合查询注入、盲注等）评估数据库的安全性，来验证这两个数据库是否对常见的SQL注入攻击提供了有效的保护措施。（本部分代码见SQL_injection.sql）

#### 创建表格

在表格的设计上，我们选择了多种数据形式，这样子能够方便后续各种SQL注入操作的生成。

SQL注入攻击是否成功与数据库中的**数据量大小**无关，所以我们只要插入几条数据观察报错情况就行。

```sql
CREATE TABLE user_table (
    id SERIAL PRIMARY KEY,             -- 整数类型
    username VARCHAR(50),              -- 字符串类型
    password VARCHAR(50),              -- 字符串类型
    email TEXT,                        -- 长文本类型
    created_at TIMESTAMP DEFAULT NOW(),-- 时间戳类型
    is_active BOOLEAN DEFAULT TRUE,    -- 布尔类型
    preferences JSON                   -- JSON 类型
);

-- 插入测试数据
INSERT INTO user_table (username, password, email, preferences)
VALUES 
('admin', 'admin123', 'admin@test.com', '{"theme": "dark", "language": "en"}'),
('user1', 'password1', 'user1@test.com', '{"theme": "light", "language": "fr"}'),
('user2', 'password2', 'user2@test.com', '{"theme": "dark", "language": "es"}');
```

#### 基础SQL注入

检测最基础的SQL注入能否直接绕过身份验证，我们测试在用户名和密码的字段处注入。

```sql
-- 模拟正常登录
SELECT * FROM user_table WHERE username = 'admin' AND password = 'admin123';

-- 模拟基础注入攻击
SELECT * FROM user_table WHERE username = 'admin' OR '1'='1'; -- 总是返回 true
```

两者结果均如下：

![image-20241218234256979](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218234256979.png)

#### 针对时间戳的注入

检测时间字段能不能通过注入然后绕过过滤，我们在时间字段中注入恶意语句。

```sql
-- 模拟查询
SELECT * FROM user_table WHERE created_at = '2024-12-01';

-- 恶意注入
SELECT * FROM user_table WHERE created_at = '2024-12-01' OR '1'='1';
```

两者结果均如下：

![image-20241218234415511](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218234415511.png)

#### JSON注入

检测JSON类型字段的注入保护能力，我们在JSON查询中尝试注入攻击。

```sql
-- 正常查询 JSON 数据
SELECT * FROM user_table WHERE preferences->>'theme' = 'dark';

-- JSON 注入
SELECT * FROM user_table WHERE preferences->>'theme' = 'dark' OR '1'='1';
```

两者结果均如下：

![image-20241218234611824](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218234611824.png)

#### 盲注

检测能否抵挡布尔盲注和时间盲注。

```sql
-- 布尔盲注
SELECT * FROM user_table WHERE username = 'admin' AND LENGTH(password) > 5;

-- 时间盲注
SELECT * FROM user_table WHERE username = 'admin' AND pg_sleep(5);
```

两者结果均如下：

没有抵挡住布尔盲注，这样可以通过不断尝试猜出密码的长度。

![image-20241218235104919](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218235104919.png)

成功抵挡住了时间盲注。

![image-20241218234925895](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218234925895.png)

#### 联合查询注入

检测是否对联合查询 (UNION SELECT) 有保护措施。

```sql
-- 恶意联合查询注入
SELECT id, username, password FROM user_table
WHERE username = 'user1'
UNION SELECT 1, table_name::text, column_name::text FROM information_schema.columns;
```

两者结果均如下：

![image-20241218235643454](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218235643454.png)

#### 参数化查询保护

检测数据库是否能通过参数化查询来有效防御注入。以下是部分java代码，完整代码见arg_query_SQLprotection.java.

```java
// 参数化查询
String sql = "SELECT * FROM user_table WHERE username = ? AND password = ?";
PreparedStatement pstmt = conn.prepareStatement(sql);
pstmt.setString(1, "admin");
pstmt.setString(2, "' OR '1'='1");
ResultSet rs = pstmt.executeQuery();

// 拼接 SQL 查询
String sql = "SELECT * FROM user_table WHERE username = '" + userInput + "'";
```

两者结果均如下：

![image-20241219143033024](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241219143033024.png)

普通拼接查询依然无法抵挡 SQL 注入。参数化查询成功防止了 SQL 注入攻击。

#### **安全函数和检查机制**

验证数据库是否存在一些防护工具来有效阻止注入。

```sql
-- 使用 PostgreSQL 的 QUOTE_LITERAL 转义
SELECT * FROM user_table WHERE username = QUOTE_LITERAL('user1'' OR ''1''=''1');
```

两者结果均如下：

![image-20241219001711656](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241219001711656.png)

使用 QUOTE_LITERAL 之后，' OR '1'='1 不会被解释为条件语句，而是当作普通字符串比较；因此查询语句只会匹配完整字符串。结果为空，说明SQL注入未能成功，数据库正确处理阻止了注入。

#### 总结

在SQL注入防御方面，两个数据库表现一致；但是**现代数据库本身不自带全面的 SQL 注入防御机制**，SQL注入的防御还是==依赖于外部工具，比如说参数化查询和预编译语句==，在这个方面两个数据库都能够正常提供防御措施。

### 加密安全性与性能

在这个模块，我们测试两个数据库对数据的加密存储能力：首先我们测试是否能正常加密，直接读取和一些常用的攻击都需要能正常抵御；然后我们测试加密后的读写性能。

### 加密性能

（代码见encryption_performance_PostgreSQL.sql与encryption_performance_OpenGauss.sql）

#### 创建测试表并插入测试数据

```sql
CREATE TABLE sensitive_data (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    address TEXT NOT NULL
);
```

```sql
INSERT INTO sensitive_data (name, email, phone, address)
SELECT
    'Name_' || i || '#',
    'Email_' || i || '@test.com',
    '12345_' || (i % 10) || '#',
    'Address_' || i || '!City_' || (i % 10)
FROM generate_series(1, 1000) AS i;
```

#### 配置数据加密

我们采取相同的加密方式，见如下代码。

PostgreSQL：

```sql
-- 启用 pgcrypto 扩展
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 使用 pgp_sym_encrypt 加密数据
UPDATE sensitive_data
SET name = pgp_sym_encrypt(name, 'Encrypt#123'),
    email = pgp_sym_encrypt(email, 'Encrypt#123'),
    phone = pgp_sym_encrypt(phone, 'Encrypt#123'),
    address = pgp_sym_encrypt(address, 'Encrypt#123');
```

OpenGauss:

```sql
-- 加密数据，使用符合要求的密钥 'Encrypt#123'
UPDATE sensitive_data
SET name = gs_encrypt_aes128(name, 'Encrypt#123'),
    email = gs_encrypt_aes128(email, 'Encrypt#123'),
    phone = gs_encrypt_aes128(phone, 'Encrypt#123'),
    address = gs_encrypt_aes128(address, 'Encrypt#123');
```

#### **加密数据性能**

仿照上面的sql语句，我们插入10万条数据，然后进行加密，查看两个数据库加密的时间。

PostgreSQL：

![image-20241220115344520](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220115344520.png)

OpenGauss：

![image-20241220115433154](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220115433154.png)

OpenGauss加密的效率远远高于PostgreSQL。

#### **测试查询性能**

测量查询加密数据所需时间，利用以下sql语句，得到查询时间。

PostgreSQL：

```sql
SELECT * FROM sensitive_data 
WHERE pgp_sym_decrypt(name::bytea, 'Encrypt#123') LIKE 'Name_1%';
```

![image-20241220115805982](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220115805982.png)

OpenGauss：

```sql
SELECT * FROM sensitive_data 
WHERE gs_decrypt_aes128(name, 'Encrypt#123') LIKE 'Name_1%';
```

![image-20241220115829492](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220115829492.png)

OpenGauss查询加密数据的效率远远高于PostgreSQL。

#### **测试更新性能**

测量更新加密数据所需时间，利用以下sql语句，得到更新时间。

PostgreSQL：

```sql
UPDATE sensitive_data
SET name = pgp_sym_encrypt('Updated_Name', 'Encrypt#123');
```

![image-20241220120053663](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220120053663.png)

OpenGauss：

```sql
UPDATE sensitive_data
SET name = gs_encrypt_aes128('Updated_Name', 'Encrypt#123');
```

![image-20241220120111209](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220120111209.png)

OpenGauss更新加密数据的效率远远高于PostgreSQL。

#### **对比启用与未启用加密功能的性能**

##### 插入数据：

PostgreSQL：

![image-20241220121527782](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220121527782.png)

![image-20241220121624491](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220121624491.png)

OpenGauss：

![image-20241220121728545](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220121728545.png)

![image-20241220122144894](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220122144894.png)

##### 更新数据：

PostgreSQL：

![image-20241220123511030](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220123511030.png)

![image-20241220122654905](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220122654905.png)

OpenGauss：

![image-20241220123638888](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220123638888.png)

![image-20241220122746153](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220122746153.png)

##### 删除数据：

PostgreSQL：

![image-20241220123546429](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220123546429.png)

![image-20241220123201076](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220123201076.png)

OpenGauss：

![image-20241220123704266](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220123704266.png)

![image-20241220123218255](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220123218255.png)

通过上述比较，发现OpenGauss的加密性能比PostgreSQL好。

##### 总结

==OpenGauss在加密相关操作的性能上具有明显优势==，对于需要高性能和加密支持的场景，OpenGauss是更优的选择。

通过查阅资料分析可能的原因：

**PostgreSQL 加密性能分析：**

PostgreSQL 使用 pgp_sym_encrypt 实现加密，支持多种算法和复杂选项，但其通用设计增加了计算开销。同时，缺乏对硬件加速的支持，无法利用现代 CPU 的 AES-NI 指令集，导致加密性能较低，特别是在大规模数据处理中表现不佳。

**OpenGauss 加密性能分析：**

OpenGauss 的 gs_encrypt_aes128 针对 AES-128 算法进行了优化，设计轻量化，专注于高效加密，减少了额外开销。同时充分利用硬件加速能力（如 AES-NI 指令集），在大规模数据处理下展现出明显的性能优势。

-------------

### 加密安全性

该部分代码见encryption_security_PostgreSQL.sql与encryption_security_OpenGauss.sql.

#### 前置工作

我们还是采取之前样式的表格，插入方法和加密方式。先把数据全都删除掉，再插入10000条数据。

#### **直接读取加密数据**

执行以下sql语句：

```sql
-- 查询加密数据
SELECT * FROM sensitive_data LIMIT 100;
```

两个数据库都成功存储了加密数据，加密后的字段会显示为二进制密文，无法直接读取，结果如下：

PostgreSQL：

![image-20241220141729709](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220141729709.png)

OpenGauss：

![image-20241220143120997](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220143120997.png)

#### **暴力破解攻击**

我们尝试不同的密钥来解密加密过的数据，用一个密钥字典来遍历所有可能的密钥，找到正确的解答密钥。我们插入100个数据，比较破解时间。

```sql
DO $$
DECLARE
    possible_key TEXT[] := ARRAY['WrongKey123', 'Encrypt#123', 'AnotherKey!']; -- 密钥字典；Encrypt#123是正确的密钥
    decrypted_name TEXT;
    current_key TEXT;
    encrypted_name BYTEA;
BEGIN
    FOR encrypted_name IN SELECT name FROM sensitive_data LOOP
        FOR current_key IN SELECT unnest(possible_key) LOOP
            BEGIN
                decrypted_name := pgp_sym_decrypt(encrypted_name, current_key);
                -- decrypted_name := gs_decrypt_aes128(encrypted_name, current_key);OpenGauss的解码接口不一样
                RAISE NOTICE '尝试密钥: %, 解密结果: %', current_key, COALESCE(decrypted_name, '解密失败');
            EXCEPTION
                WHEN others THEN
                    RAISE NOTICE '密钥 % 无法解密，错误信息: %', current_key, SQLERRM;
            END;
        END LOOP;
    END LOOP;
END $$;
```

PostgreSQL：

![image-20241220163928388](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220163928388.png)

![image-20241220164127129](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220164127129.png)

OpenGauss：

![image-20241220165545924](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220165545924.png)

![image-20241220165502527](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220165502527.png)

暴力解码OpenGauss需要更多时间，可以认为这个测试中OpenGauss的安全性较高。

#### **离线破解攻击**

离线攻击指攻击者获取了数据库中的加密数据后，利用外部计算资源（而非数据库直接解密接口）尝试破解；这个攻击所需要的时间和加密算法的强度、加密密钥的长度以及哈希/加密函数的复杂性有关。

还是利用之前的数据，但是我们把密钥个数增加到10个，其中一个是有用的。

导出csv表格以离线测试：

```sql
---- PostgreSQL导出表格
copy (SELECT id, name, email, phone, address FROM sensitive_data) TO '/Users/ruiyuhan/Desktop/temp_code/sensitive_table_PostgreSQL.csv' DELIMITER ',' CSV HEADER;
```

```sql
---- OpenGauss导出表格
（OpenGauss 出于安全考虑禁用了 COPY 命令对文件的直接读写操作）
在命令行中连接到数据库，执行以下命令
\copy (SELECT id, name, email, phone, address FROM sensitive_data) 
TO '/Users/ruiyuhan/Desktop/temp_code/sensitive_table_OpenGauss.csv' 
DELIMITER ',' CSV HEADER;
```

PostgreSQL：

![image-20241220182301401](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220182301401.png)

OpenGauss：

![image-20241220195030969](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220195030969.png)

离线解码OpenGauss也是需要更多时间，也可以认为这个测试中==OpenGauss的安全性较高。==

#### **密钥管理和泄露测试**

我们可以做以下的几个实验：

- 普通查询泄漏密钥
- SQL注入泄漏密钥
- 数据库备份泄露密钥

前两个我们在上一个板块中都已经测试过：

数据库权限控制不当的情况下可能会因为普通查询泄漏密钥；恶意的 SQL 代码可以获取敏感数据，因此需要保护工具。

数据库备份泄露密钥，这个主要是由于管理者人为因素没有管理好备份，攻击者也可以从备份中还原密钥：

```cmd
pg_restore -d target_database backup_file.dump
gs_restore -d target_database backup_file
```

再结合cat命令就能够得到敏感信息：

```cmd
#对应具体的路径信息
cat /etc/postgresql.conf 
cat /etc/opengauss/gaussdb.conf
```

这些两个数据库都是不可避免导致泄漏。

#### 密钥更改与重新加密

如果遇到密钥泄漏，我们会更换密钥，具体操作就是先解密再用新的密钥加密；以下是比较两个数据库更改密钥用时：

PostgreSQL：

![image-20241220201139264](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220201139264.png)

OpenGauss：

![image-20241220201806742](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241220201806742.png)

更改密钥的时间接近。

#### 总结

总体而言，==OpenGauss密钥安全性高于PostgreSQL==，这和社区文档中提到的优势相符合。

## 易用性

### 安装与部署难度

这一点==**OpenGauss完败**。==

PostgreSQL在macbook上安装特别简单，直接用homebrew包管理工具就行了，之后命令行直接可以使用。

而OpenGauss的部署简直就是disaster，我两种方式都尝试了：docker镜像还是老师部署了，就是拉个镜像都会有各种问题要注意，还只能3.0.0，很多功能都存在阉割情况，要做比较很烦（后面的分区表会提到）。而华为云上更是繁琐，远程服务器的部署要走几页文档，然后还因为未知的原因失败了，更不用提前期还要在网站上搞很多注册。

### 运维工具支持

在测试性能的过程中，我实际上尝试过PostgreSQL自带的基准测试工具`pgbench`的，TPS和Latency、并发一下子都能测出来，能够很好模拟真实的数据库负载来评估性能。

只需要短短两行代码，得到的结果也能很详细：

```cmd
pgbench -i -s 10 -U <username> -d <dbname>
pgbench -c 10 -j 2 -T 60 -U <username> -d <dbname>
# 参数可以调整
```

```cmd
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 10
query mode: simple
number of clients: 10
number of threads: 2
duration: 60 s
number of transactions actually processed: 123456
latency average = 1.23 ms
tps = 1234.56 (including connections establishing)
```

而**OpenGauss就不能使用这个工具**，会一直因为有个注册表列名冲突无法进行，尽管OpenGauss基于PostgreSQL开发，但不能用PostgreSQL自带的测试用具。

OpenGauss提供了一个压力测试工具`gs_prober`，这个工具更多是用来监控数据库运行状态的，而不是模拟复杂事物压力。大致是这么使用：

```cmd
gs_prober -U gaussdb -p 15432
```

优势是可以监控 CPU、内存、I/O 等多方面的性能状态，并能够提供图表输出。

```cmd
===========================================
       OpenGauss Performance Monitoring
===========================================

Time: 2024-12-22 14:35:45
-------------------------------------------
Database: postgres
User: gaussdb
Port: 5432
-------------------------------------------

CPU Usage: 35.6% (User: 20.3%, System: 15.3%)
Memory Usage: 3.5 GB / 16 GB (21.9%)
Disk I/O: Read: 100 MB/s | Write: 50 MB/s
Active Connections: 35 / 200
Query TPS: 1200
Query Latency: Avg: 1.3 ms | P95: 2.5 ms | P99: 3.8 ms
Cache Hit Rate: 99.2%
Locks: 5 waiting | 50 total
-------------------------------------------

Detailed Metrics:
- Transaction Commit: 1100 TPS
- Transaction Rollback: 100 TPS
- Temp Files Created: 25 MB
- Checkpoints: 2

===========================================
```

总体来说还是PostgreSQL的运维工具更全面，毕竟社区更加成熟。

### 日志

| 对比项         | PostgreSQL                                                   | openGauss                                                    |
| -------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 日志类型       | 运行日志、WAL 日志、事务提交日志                             | 系统日志、审计日志、Trace日志、黑匣子日志、WAL日志、性能日志 |
| 日志配置灵活性 | 通过 `postgresql.conf` 配置，支持 log_directory、log_filename、log_statement 等参数 | 配置功能继承 PostgreSQL，额外支持 log_file_mode、log_truncate_on_rotation 等参数 |
| 日志管理能力   | 简单日志轮转，通过 log_rotation_age 和 log_rotation_size 控制 | 更细致日志分类，如性能日志、黑匣子日志，支持资源监控（内存、CPU、I/O） |
| 并发场景支持   | 记录并发查询和锁等待日志                                     | 增强并发支持，适合高吞吐场景，提供审计日志和 Trace 日志      |
| 诊断与调试能力 | 提供 SQL 执行时间、行数和计划信息，通过 log_statement_stats 配置启用 | 增强诊断透明度，提供 Trace 日志和黑匣子日志                  |
| 性能日志支持   | 默认不记录性能相关日志                                       | 提供性能日志，记录资源使用（CPU、内存等）和 I/O 性能         |
| 企业级扩展能力 | 满足通用数据库日志需求                                       | 增强日志功能，支持审计日志、性能日志和黑匣子日志             |

总体而言，openGauss 在继承 PostgreSQL 日志系统优点的基础上，==多加了日志类型和管理功能==，提供了更为全面的日志记录和分析能力，满足企业级应用对数据库监控和维护的需求。

## 可拓展性

### 分区表性能

模拟一个执行大量交易记录的财务系统，按照时间范围来进行分区。我们先创建好主表，然后得保证主键约束满足分区表的要求，才能正常创建分区表。

值得一说的是，OpenGauss 是基于 PostgreSQL9.2.4 的内核开发的，在 PostgreSQL10 之前要达到实现分区表的效果可以有两种方式，一种是使用继承的触发器函数来实现，一种是安装 pg_pathman 的插件来实现，直到 PostgreSQL10 才引入了 partition 的语法。（https://www.cnblogs.com/renxyz/p/18072573）~~我这个3.0.0镜像要折腾半天才行~~

```sql
-- 创建主表 transactions，按 created_at 字段进行范围分区
CREATE TABLE transactions (
    id SERIAL,                      
    user_id INT NOT NULL,            
    amount NUMERIC(10, 2) NOT NULL,   
    created_at TIMESTAMP NOT NULL,    
    PRIMARY KEY (id, created_at)      -- 主键包含分区键 created_at
) PARTITION BY RANGE (created_at);     -- 按时间范围进行分区
```

```sql
-- 创建分区表：2024 年第一季度
CREATE TABLE transactions_2024_q1 PARTITION OF transactions
FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

-- 创建分区表：2024 年第二季度
CREATE TABLE transactions_2024_q2 PARTITION OF transactions
FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

-- 创建分区表：2024 年第三季度
CREATE TABLE transactions_2024_q3 PARTITION OF transactions
FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');

-- 创建分区表：2024 年第四季度
CREATE TABLE transactions_2024_q4 PARTITION OF transactions
FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');
```

接下来我们插入随机生成的数据，一共100万条，因为均匀性原理，在两个数据库中插入的数据不同但是每个分区表中数据的数量最终分布均匀。

```sql
-- 插入模拟数据
INSERT INTO transactions (user_id, amount, created_at)
SELECT
    i % 1000,                 
    RANDOM() * 1000,           
    TIMESTAMP '2024-01-01' +  
    (RANDOM() * INTERVAL '365 days')
FROM generate_series(1, 1000000) AS i;
```

#### 分组统计查询

执行以下代码：

```sql
---- 分组统计查询
SELECT DATE_TRUNC('quarter', created_at) AS quarter, SUM(amount) AS total_amount
FROM transactions
GROUP BY DATE_TRUNC('quarter', created_at)
ORDER BY quarter;
```

PostgreSQL：

![image-20241219202708401](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241219202708401.png)

OpenGauss：

![image-20241219202844023](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241219202844023.png)

#### 索引优化测试

执行以下代码：

```sql
-- 创建索引
CREATE INDEX idx_user_id ON transactions (user_id);

-- 测试索引查询
SELECT * FROM transactions WHERE user_id = 123;
```

PostgreSQL：

![image-20241219202057528](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241219202057528.png)

OpenGauss：

![image-20241219203050893](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241219203050893.png)

### 动态分区拓展

我们在以上表格中添加一个新的分区，测试动态添加分区的效率。

以下代码添加新的分区，并且在这个分区中插入数据：

```sql
---- 动态添加新分区
-- 添加 2025 年第一季度分区
CREATE TABLE transactions_2025_q1 PARTITION OF transactions
FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');

-- 插入新的数据
INSERT INTO transactions (user_id, amount, created_at)
SELECT
    i % 1000,
    RANDOM() * 1000,
    TIMESTAMP '2025-01-01' + (RANDOM() * INTERVAL '90 days')
FROM generate_series(1, 100000) AS i;
```

执行以下代码：

```sql
-- 验证新分区查询能力
SELECT * FROM transactions WHERE created_at BETWEEN '2025-01-01' AND '2025-03-31';
```

PostgreSQL：

![image-20241219202135182](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241219202135182.png)

OpenGauss：

![image-20241219203213185](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241219203213185.png)

#### 总结

==分区表的性能测出来的普通表格基本相似==，总体是OpenGauss略慢于PostgreSQL；但是分区表索引查询性能OpenGauss还是有一定优势，这个在之前索引的实验中也能够验证。

## 性能优化能力

### 配置调优

在前文那么多测试中，我们一直使用的是两个数据库默认的参数设置，但是我们没有去调查这个参数到底是多少。我们查询以下三个关键参数：

```sql
SHOW shared_buffers;--数据库缓存的内存
SHOW work_mem;-- 每个查询的内存限制
SHOW max_connections;-- 最大连接数
```

|                 | PostgreSQL | OpenGauss |
| --------------- | ---------- | --------- |
| shared_buffers  | 128MB      | 32MB      |
| work_mem        | 4MB        | 64MB      |
| max_connections | 100        | 200       |

OpenGauss的`shared_buffers`小，它是用于缓存数据的内存区域，用于存储数据库中经常访问的数据、索引和查询结果；因此OpenGaussI/O操作频繁，这个和我们之前在性能一部分实验的结论一致。

`work_mem `用于存放排序数据的内存大小，我们之前测试的任务对排序没有很高的要求，所以差异感知不明显。

作为一个严谨的比较，我们需要把这些配置调成一致的状态，这样的测试更加严谨。因此，我们下面会把两个数据库每次设置为三组不同的配置，分别测试在这三组配置的情况下的性能优化表现；这三组配置中只有一个会改变，达到控制变量的目的。这个通过修改配置文件达到，然后重启数据库。

```sql
SET shared_buffers TO '64MB';
SET work_mem TO '16MB';
SET max_connections TO 200;
```

#### shared_buffers

我们采用之前吞吐量、延迟的java程序来测试；对之前的java程序做了改动，可以一次测出TPS和latency；设置50个线程，每个线程10000个事务量。（代码见perfromance_test.java）

|                 | 组1  | 组2  | 组3   |
| --------------- | ---- | ---- | ----- |
| shared_buffers  | 32MB | 64MB | 128MB |
| work_mem        | 16MB | 16MB | 16MB  |
| max_connections | 100  | 100  | 100   |

TPS：

| shared_buffers | PostgreSQL | OpenGauss |
| -------------- | ---------- | --------- |
| 32MB           | 29815      | 9107      |
| 64MB           | 29453      | 8940      |
| 128MB          | 28770      | 9081      |

Latency：

| shared_buffers | PostgreSQL | OpenGauss |
| -------------- | ---------- | --------- |
| 32MB           | 1.35ms     | 4.96ms    |
| 64MB           | 1.37ms     | 5.06ms    |
| 128MB          | 1.40ms     | 4.97ms    |

两个数据库对于`shared_buffers`提升，==TPS和Latency不但没有提升，而且还存在略微下降==；但是cpu、内存占用变低了一些。

这可能是因为在测试场景中，较大的`shared_buffers`并未充分利用，导致性能提升有限。然而，较大的`shared_buffers`确实降低了CPU和内存的占用，表明缓存资源的调整对系统资源的影响较为明显。

- **PostgreSQL**在较大的`shared_buffers`下，TPS依然保持在较高水平，并且延迟变化幅度较小，说明对缓存的优化能力较为稳定。

- **OpenGauss**的TPS和延迟随`shared_buffers`变化，但整体性能略逊于PostgreSQL。可能因为OpenGauss在I/O缓存管理上的默认优化力度较弱，因此`shared_buffers`对其影响更为显著。

#### work_mem

我们均设置`shared_buffers=128MB`，`max_connections=100`；对`work_men`进行调整，执行排序查询语句记录时间。

我们设计以下测试表，执行以下查询语句：（代码见revise_configure.sql）

```sql
CREATE TABLE test_data AS
SELECT
    id,
    random() AS value,
    md5(random()::text) AS text_column
FROM generate_series(1, 1000000) AS id;

ANALYZE test_data;
```

```sql
DO $$
DECLARE
    work_mem_values INTEGER[] := ARRAY[1024, 2048, 4096, 8192, 16384]; -- work_mem 值（单位：KB）
    query TEXT := 'SELECT * FROM test_data ORDER BY value LIMIT 10000;';
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    execution_time INTERVAL;
BEGIN
    FOR i IN 1..array_length(work_mem_values, 1) LOOP
        EXECUTE format('SET work_mem = %s;', work_mem_values[i]); 
        start_time := clock_timestamp();
        EXECUTE query;
        end_time := clock_timestamp(); 
        execution_time := end_time - start_time; 
        RAISE NOTICE 'work_mem: % MB | Execution Time: % 秒',
            work_mem_values[i] / 1024, 
            EXTRACT(EPOCH FROM execution_time); 
    END LOOP;
END $$;
```

PostgreSQL：

![image-20241222025241235](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241222025241235.png)

OpenGauss：

![image-20241222025504218](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241222025504218.png)

**可以发现两个数据库随着`work_mem`的提高，执行排序查询的速度也增快**，这个与我们的预期一致。但是OpenGauss的查询执行时间在较大的`work_mem`下还是差于PostgreSQL。从1MB到16MB，PostgreSQL查询速度提升至5倍，而OpenGauss只提升至2倍。

#### 总结

PostgreSQL在配置调优中表现更为稳定高效，合理调整参数后，TPS和延迟表现优于OpenGauss。尽管OpenGauss默认配置性能稍弱，但优化后在排序查询等场景中表现出不错的潜力。总之，PostgreSQL在优化策略上更具优势。

### 查询计划分析

在之前的实验中我们也使用了很多explain analysise语句，在这个板块我们仔细分析它们能够带给我们的信息。

PostgreSQL

![image-20241217210721983](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217210721983.png)

![image-20241218103222967](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218103222967.png)

OpenGauss

![image-20241217210926309](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241217210926309.png)

![image-20241218103323258](/Users/ruiyuhan/Library/Application Support/typora-user-images/image-20241218103323258.png)

| **比较项**             | **PostgreSQL**                                         | **OpenGauss**                                                |
| ---------------------- | ------------------------------------------------------ | ------------------------------------------------------------ |
| **层次化结构**         | 层次清晰，易于理解；提供详细的过滤、排序和扫描步骤     | 层次清晰，额外提供并行化的详细信息                           |
| **执行成本估算**       | 提供了详细的 `cost` 信息，便于调优                     | 提供了类似的成本信息，但对并行化的成本分配更透明             |
| **执行时间与行数**     | `actual time` 和 `rows` 信息直观，便于分析预测准确性   | 同样详细，但额外提供线程级的性能统计                         |
| **排序与过滤优化信息** | 提供排序方法和过滤条件的详细信息，但没有算法优化的描述 | 提供优化排序算法（如 `top-N heapsort`），更便于分析排序性能  |
| **资源使用信息**       | 提供磁盘 I/O 消耗信息，便于评估资源不足的情况          | 提供内存使用的详细信息，便于调优内存配置                     |
| **并行化信息**         | 并行化支持较弱，计划中无详细描述                       | 并行化支持强，提供详细的线程分配与合并信息                   |
| **透明性与可操作性**   | 透明性高，细节丰富，适合调优                           | 对并行查询透明性更高，但部分高级查询的计划信息可能不如 PostgreSQL 直观 |

#### **总结**

**PostgreSQL 查询计划的特点：**

- 提供了非常详细的查询步骤描述，适合评估简单和中等复杂度查询。

- 缺点是对并行化支持的透明性较弱。

**OpenGauss 查询计划的特点：**

- 对并行化的支持和描述能力更强，在复杂查询中提供了更多优化算法的细节。
- 缺点是部分子查询和窗口函数的分析信息没有 PostgreSQL 完整。

## 项目总结

最后写一段总结，结束两个数据库的对比。

| **比较维度**     | **PostgreSQL**                                               | **OpenGauss**                                              |
| ---------------- | ------------------------------------------------------------ | ---------------------------------------------------------- |
| **性能**         | **插入效率**：事务吞吐量高，CPU 和内存使用率较高，偏向激进   | **插入效率**：插入速率稍慢，但资源使用更稳定               |
|                  | **查询效率**：复杂查询响应速度快，尤其在排序和索引优化上表现佳 | **查询效率**：查询速度稍逊，但排序内存消耗大，适合简单查询 |
|                  | **并发性能**：高并发下吞吐量优于 OpenGauss                   | **并发性能**：高并发时锁管理有一定瓶颈                     |
| **可靠性**       | 满足 ACID 特性：隔离级别严格，支持故障恢复                   | 满足 ACID 特性：隔离级别表现一致，支持故障恢复             |
|                  | **日志恢复**：崩溃后数据恢复速度快                           | **日志恢复**：恢复机制同样可靠，数据完整性得到保障         |
| **安全性**       | **权限管理**：支持表级、列级和行级权限                       | **权限管理**：支持更细粒度的权限分配                       |
|                  | **SQL 注入保护**：通过参数化查询和工具提供基本防护           | **SQL 注入保护**：防护措施一致，依赖外部工具               |
|                  | **加密性能**：加密和解密效率较低                             | **加密性能**：优化 AES 加密，支持硬件加速，性能更优        |
|                  | **加密安全性**：离线破解难度较低                             | **加密安全性**：离线破解所需时间更长                       |
| **可扩展性**     | **分区表性能**：分区表性能稳定，索引查询更快                 | **分区表性能**：动态分区扩展效率较高，索引优化效果显著     |
|                  | **并发处理能力**：更高并发支持，适合大事务操作               | **并发处理能力**：稳定性更强，但吞吐量略低                 |
| **易用性**       | **安装与部署**：极为简便，支持多平台                         | **安装与部署**：部署复杂，尤其是在 Mac 上，依赖 Docker     |
|                  | **运维工具支持**：pgbench 工具完备，便于基准测试和优化       | **运维工具支持**：gs_prober 支持性能监控，但缺乏基准测试   |
|                  | **日志功能**：日志配置灵活，适合通用需求                     | **日志功能**：日志分类更丰富，支持企业级审计和性能监控     |
| **性能优化能力** | **配置调优**：调整缓存、内存参数后表现显著提升               | **配置调优**：优化效果不明显，但排序查询等场景潜力较大     |
|                  | **查询计划分析**：提供详细透明的执行计划信息                 | **查询计划分析**：并行化信息透明，适合高负载调优           |

-------------

- **PostgreSQL** 在性能、查询效率、并发处理能力上表现更强，适合对性能要求高的场景；同时，其安装部署和运维工具更加成熟，查询计划透明度高，调优操作便捷。
- **OpenGauss** 在安全性、加密性能和分区表优化方面更具优势，日志分类更丰富，适合企业级应用，尤其是注重稳定性和安全性的场景。但其在性能优化和复杂查询效率方面与 PostgreSQL 仍有差距。

## 项目心得

在这个项目中，我的收获确实挺多。最开始可能只是单纯地想看看两个数据库的性能谁更好，后来发现性能真的不是唯一的评判标准。数据库的设计和选择，其实更多是一个综合权衡的过程，比如安全性、扩展性、易用性这些维度，可能在不同场景下比性能还重要。就像OpenGauss，虽然在一些性能指标上不如PostgreSQL，但它在加密性能、日志管理、权限控制上确实让我眼前一亮，这些都是一些企业场景下更需要的东西。同样，PostgreSQL的表现也证明了它为什么是社区那么活跃的开源数据库。

最后，这个项目最大的感触就是，衡量一个数据库好不好，真的不能只盯着单个指标看，==而是要从多个维度去评估它到底适不适合你的实际需求。==

