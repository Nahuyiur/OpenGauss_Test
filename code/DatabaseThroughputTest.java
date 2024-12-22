import java.sql.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class DatabaseThroughputTest {
//    选择需要用到的数据库，切换
    private static final String DB_URL = "jdbc:postgresql://localhost:5432/postgres";
    private static final String USER = "ruiyuhan";
    private static final String PASSWORD = "ruiyuhan111";

//    private static final String DB_URL = "jdbc:postgresql://localhost:15432/postgres";
//    private static final String USER = "gaussdb";
//    private static final String PASSWORD = "Ruiyuhan123@";

    private static final int NUM_THREADS = 50;
    private static final int TRANSACTIONS_PER_THREAD = 10000;

    public static void main(String[] args) {
        System.out.println("Starting throughput test...");
        ExecutorService executor = Executors.newFixedThreadPool(NUM_THREADS);

        long startTime = System.currentTimeMillis();
        for (int i = 0; i < NUM_THREADS; i++) {
            executor.submit(new TransactionTask());
        }

        executor.shutdown();
        try {
            executor.awaitTermination(1, TimeUnit.HOURS);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        long endTime = System.currentTimeMillis();
        long totalTime = endTime - startTime;

        int totalTransactions = NUM_THREADS * TRANSACTIONS_PER_THREAD;
        double tps = totalTransactions / (totalTime / 1000.0);

        System.out.println("Total Transactions: " + totalTransactions);
        System.out.println("Total Time: " + totalTime / 1000.0 + " seconds");
        System.out.println("Throughput (TPS): " + tps);
    }

    static class TransactionTask implements Runnable {
        @Override
        public void run() {
            try (Connection conn = DriverManager.getConnection(DB_URL, USER, PASSWORD)) {
                conn.setAutoCommit(false);

                for (int i = 0; i < TRANSACTIONS_PER_THREAD; i++) {
                    // INSERT 操作
                    try (PreparedStatement insertStmt = conn.prepareStatement(
                            "INSERT INTO accounts (account_name, balance) VALUES (?, ?)")) {
                        insertStmt.setString(1, "User_" + Thread.currentThread().getId() + "_" + i);
                        insertStmt.setDouble(2, Math.random() * 10000);
                        insertStmt.executeUpdate();
                    }

                    // UPDATE 操作
                    try (PreparedStatement updateStmt = conn.prepareStatement(
                            "UPDATE accounts SET balance = balance + 1 WHERE id = ?")) {
                        updateStmt.setInt(1, (int) (Math.random() * 1000) + 1);
                        updateStmt.executeUpdate();
                    }

                    // DELETE 操作
                    try (PreparedStatement deleteStmt = conn.prepareStatement(
                            "DELETE FROM accounts WHERE id = ?")) {
                        deleteStmt.setInt(1, (int) (Math.random() * 1000) + 1);
                        deleteStmt.executeUpdate();
                    }

                    conn.commit();
                }
            } catch (SQLException e) {
                e.printStackTrace();
            }
        }
    }
}