import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.sql.*;
import java.util.concurrent.*;

public class DatabaseLatencyTest {
    //    选择需要用到的数据库，切换
    private static final String DB_URL = "jdbc:postgresql://localhost:5432/postgres";
    private static final String USER = "ruiyuhan";
    private static final String PASSWORD = "ruiyuhan111";

//    private static final String DB_URL = "jdbc:postgresql://localhost:15432/postgres";
//    private static final String USER = "gaussdb";
//    private static final String PASSWORD = "Ruiyuhan123@";


    private static final int NUM_THREADS = 100;
    private static final int TRANSACTIONS_PER_THREAD = 3000;
    private static final String LATENCY_FILE = "latency_data1.txt";

    public static void main(String[] args) {
        System.out.println("Starting latency test...");

        ExecutorService executor = Executors.newFixedThreadPool(NUM_THREADS);

        long startTime = System.currentTimeMillis();
        for (int i = 0; i < NUM_THREADS; i++) {
            executor.submit(new TransactionTask(LATENCY_FILE));
        }

        executor.shutdown();
        try {
            executor.awaitTermination(1, TimeUnit.HOURS);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        long endTime = System.currentTimeMillis();
        long totalTime = endTime - startTime;

        System.out.println("Total Transactions: " + (NUM_THREADS * TRANSACTIONS_PER_THREAD));
        System.out.println("Total Time: " + totalTime / 1000.0 + " seconds");
        System.out.println("Latency data written to " + LATENCY_FILE);
    }

    static class TransactionTask implements Runnable {
        private final String outputFile;

        TransactionTask(String outputFile) {
            this.outputFile = outputFile;
        }

        @Override
        public void run() {
            try (Connection conn = DriverManager.getConnection(DB_URL, USER, PASSWORD)) {
                conn.setAutoCommit(false);

                for (int i = 0; i < TRANSACTIONS_PER_THREAD; i++) {
                    long transactionStart = System.nanoTime();

                    try {
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
                    } catch (SQLException e) {
                        conn.rollback();  // 出现异常时回滚
                        e.printStackTrace();
                    }

                    long transactionEnd = System.nanoTime();
                    double responseTime = (transactionEnd - transactionStart) / 1_000_000.0;

                    writeResponseTimeToFile(responseTime);
                }
            } catch (SQLException e) {
                e.printStackTrace();
            }
        }

        private synchronized void writeResponseTimeToFile(double responseTime) {
            try (BufferedWriter writer = new BufferedWriter(new FileWriter(outputFile, true))) {
                writer.write(String.format("%.2f\n", responseTime));
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }
}