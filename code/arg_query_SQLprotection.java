import java.sql.*;

public class arg_query_SQLprotection {

    //    选择需要用到的数据库，切换
//    private static final String DB_URL = "jdbc:postgresql://localhost:5432/postgres";
//    private static final String USER = "ruiyuhan";
//    private static final String PASSWORD = "ruiyuhan111";

    private static final String DB_URL = "jdbc:postgresql://localhost:15432/postgres";
    private static final String USER = "gaussdb";
    private static final String PASSWORD = "Ruiyuhan123@";
    public static void main(String[] args) {
        try (Connection conn = DriverManager.getConnection(DB_URL, USER, PASSWORD)) {
            // 模拟用户输入
            String normalUsername = "admin";
            String injectedPassword = "' OR '1'='1";
            String userInputForInjection = "admin' OR '1'='1"; // 恶意注入的用户名

            // 验证普通拼接查询（容易受到 SQL 注入攻击）
            System.out.println("=== 测试普通拼接查询（SQL 注入漏洞） ===");
            testVulnerableQuery(conn, normalUsername, injectedPassword);
            testVulnerableQuery(conn, userInputForInjection, "irrelevant");

            // 验证参数化查询（有效防御 SQL 注入）
            System.out.println("=== 测试参数化查询（防止 SQL 注入） ===");
            testSafeQuery(conn, normalUsername, injectedPassword);
            testSafeQuery(conn, userInputForInjection, "irrelevant");

        } catch (SQLException e) {
            e.printStackTrace();
        }
    }


    //测试普通拼接查询（容易受到 SQL 注入攻击）
    private static void testVulnerableQuery(Connection conn, String username, String password) {
        String sql = "SELECT * FROM user_table WHERE username = '" + username + "' AND password = '" + password + "'";
        System.out.println("执行的 SQL: " + sql);
        try (Statement stmt = conn.createStatement(); ResultSet rs = stmt.executeQuery(sql)) {
            printResults(rs);
        } catch (SQLException e) {
            System.out.println("普通拼接查询出错: " + e.getMessage());
        }
    }

    //测试参数化查询（防止 SQL 注入）
    private static void testSafeQuery(Connection conn, String username, String password) {
        String sql = "SELECT * FROM user_table WHERE username = ? AND password = ?";
        System.out.println("执行参数化查询...");
        try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
            pstmt.setString(1, username);
            pstmt.setString(2, password);
            try (ResultSet rs = pstmt.executeQuery()) {
                printResults(rs);
            }
        } catch (SQLException e) {
            System.out.println("参数化查询出错: " + e.getMessage());
        }
    }

    private static void printResults(ResultSet rs) throws SQLException {
        if (!rs.isBeforeFirst()) {
            System.out.println("没有查询到任何结果。");
            return;
        }
        while (rs.next()) {
            System.out.println("ID: " + rs.getInt("id") +
                    ", Username: " + rs.getString("username") +
                    ", Password: " + rs.getString("password"));
        }
    }
}