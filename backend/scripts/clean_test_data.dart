import 'package:postgres/postgres.dart';

/// Dart script to clean test users from database
/// Run with: dart backend/scripts/clean_test_data.dart
Future<void> main() async {
  const dbHost = String.fromEnvironment('DB_HOST', defaultValue: 'localhost');
  const dbPort = String.fromEnvironment('DB_PORT', defaultValue: '5432');
  const dbName = String.fromEnvironment('DB_NAME', defaultValue: 'messenger_db');
  const dbUser = String.fromEnvironment('DB_USER', defaultValue: 'messenger_user');
  const dbPassword = String.fromEnvironment('DB_PASSWORD', defaultValue: 'messenger_password');

  print('[INFO] Connecting to $dbName on $dbHost:$dbPort');

  late PostgreSQLConnection conn;
  try {
    conn = PostgreSQLConnection(
      dbHost,
      int.parse(dbPort),
      dbName,
      username: dbUser,
      password: dbPassword,
    );
    await conn.open();
    print('[✓] Connected to database');

    // Delete all test accounts
    final deleted = await conn.execute(
      '''DELETE FROM "users" 
         WHERE email LIKE @pattern1 
         OR email LIKE @pattern2 
         OR username LIKE @pattern1 
         OR username LIKE @pattern2''',
      substitutionValues: {
        'pattern1': 'testuser%',
        'pattern2': 'test%',
      },
    );

    print('[✓] Deleted $deleted test accounts');

    // Show remaining count
    final remaining = await conn.query('SELECT COUNT(*) FROM "users"');
    print('[✓] Remaining users: ${remaining[0][0]}');

    // List remaining users
    final users = await conn.query(
      'SELECT username, email FROM "users" ORDER BY created_at DESC LIMIT 10',
    );
    print('[INFO] Recent accounts:');
    for (final row in users) {
      print('  - ${row[0]} (${row[1]})');
    }

    await conn.close();
    print('[✓] Cleanup complete');
  } catch (e) {
    print('[ERROR] $e');
    rethrow;
  }
}
