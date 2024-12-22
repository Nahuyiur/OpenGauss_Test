import java.sql.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

public class perfromance_test {

    // 配置数据库连接信息
//    private static final String DB_URL = "jdbc:postgresql://localhost:5432/postgres";
//    private static final String USER = "ruiyuhan";
//    private static final String PASSWORD = "ruiyuhan111";
        private static final String DB_URL = "jdbc:postgresql://localhost:15432/postgres";
    private static final String USER = "gaussdb";
    private static final String PASSWORD = "Ruiyuhan123@";

    // 测试配置
    private static final int NUM_THREADS = 50;
    private static final int TRANSACTIONS_PER_THREAD = 10000;

    public static void main(String[] args) {
        System.out.println("Starting database performance tests...");

        ExecutorService executor = Executors.newFixedThreadPool(NUM_THREADS);

        long startTime = System.currentTimeMillis();

        AtomicLong totalTransactions = new AtomicLong(0);
        AtomicLong totalLatency = new AtomicLong(0);

        for (int i = 0; i < NUM_THREADS; i++) {
            executor.submit(new TransactionTask(totalTransactions, totalLatency));
        }

        executor.shutdown();
        try {
            executor.awaitTermination(1, TimeUnit.HOURS);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        long endTime = System.currentTimeMillis();
        long totalTime = endTime - startTime;

        long totalTxns = totalTransactions.get();
        double tps = totalTxns / (totalTime / 1000.0);

        double avgLatency = totalLatency.get() / (double) totalTxns;

        System.out.println("Total Transactions: " + totalTxns);
        System.out.println("Total Time: " + totalTime / 1000.0 + " seconds");
        System.out.println("Throughput (TPS): " + tps);
        System.out.println("Average Latency (ms): " + avgLatency);
    }

    static class TransactionTask implements Runnable {
        private final AtomicLong totalTransactions;
        private final AtomicLong totalLatency;

        TransactionTask(AtomicLong totalTransactions, AtomicLong totalLatency) {
            this.totalTransactions = totalTransactions;
            this.totalLatency = totalLatency;
        }

        @Override
        public void run() {
            try (Connection conn = DriverManager.getConnection(DB_URL, USER, PASSWORD)) {
                conn.setAutoCommit(false);

                for (int i = 0; i < TRANSACTIONS_PER_THREAD; i++) {
                    long transactionStart = System.nanoTime();

                    try (PreparedStatement insertStmt = conn.prepareStatement(
                            "INSERT INTO accounts (account_name, balance) VALUES (?, ?)")) {
                        insertStmt.setString(1, "User_" + Thread.currentThread().getId() + "_" + i);
                        insertStmt.setDouble(2, Math.random() * 10000);
                        insertStmt.executeUpdate();
                    }

                    try (PreparedStatement updateStmt = conn.prepareStatement(
                            "UPDATE accounts SET balance = balance + 1 WHERE id = ?")) {
                        updateStmt.setInt(1, (int) (Math.random() * 1000) + 1);
                        updateStmt.executeUpdate();
                    }

                    try (PreparedStatement deleteStmt = conn.prepareStatement(
                            "DELETE FROM accounts WHERE id = ?")) {
                        deleteStmt.setInt(1, (int) (Math.random() * 1000) + 1);
                        deleteStmt.executeUpdate();
                    }

                    conn.commit();

                    long transactionEnd = System.nanoTime();
                    double responseTime = (transactionEnd - transactionStart) / 1_000_000.0; // 毫秒

                    totalTransactions.incrementAndGet();
                    totalLatency.addAndGet((long) responseTime);
                }
            } catch (SQLException e) {
                e.printStackTrace();
            }
        }
    }
}