import 'dart:io';
import 'package:postgres/postgres.dart';

/// Database cleanup script for removing test accounts
/// 
/// Usage:
///   dart run scripts/cleanup_accounts.dart all           # Delete all accounts
///   dart run scripts/cleanup_accounts.dart email <email> # Delete specific email
///   dart run scripts/cleanup_accounts.dart unverified    # Delete unverified only
///   dart run scripts/cleanup_accounts.dart count         # Show account count

Future<void> main(List<String> args) async {
  const host = 'localhost';
  const port = 5432;
  const database = 'messenger_db';
  const username = 'messenger_user';
  const password = 'messenger_password';

  try {
    print('╔═══════════════════════════════════════════════════════╗');
    print('║        Database Account Cleanup Script              ║');
    print('╚═══════════════════════════════════════════════════════╝\n');

    final connection = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    try {
      if (args.isEmpty) {
        _printUsage();
        return;
      }

      final command = args[0].toLowerCase();

      switch (command) {
        case 'all':
          await _deleteAll(connection);
          break;
        case 'email':
          if (args.length < 2) {
            print('❌ Error: Email required');
            print('Usage: dart run scripts/cleanup_accounts.dart email <email>');
            exit(1);
          }
          await _deleteByEmail(connection, args[1]);
          break;
        case 'unverified':
          await _deleteUnverified(connection);
          break;
        case 'count':
          await _showCount(connection);
          break;
        case 'list':
          await _listAccounts(connection);
          break;
        case 'help':
          _printUsage();
          break;
        default:
          print('❌ Unknown command: $command');
          _printUsage();
          exit(1);
      }
    } finally {
      await connection.close();
    }

    print('\n✓ Operation completed successfully\n');
  } catch (e) {
    print('\n❌ Error: $e\n');
    exit(1);
  }
}

Future<void> _deleteAll(Connection connection) async {
  print('[INFO] Deleting all accounts...\n');

  // Get count before deletion
  final countBefore = await connection.query<int>(
    'SELECT COUNT(*) FROM users',
  );
  final before = countBefore.first.first ?? 0;

  // Delete and reset sequence
  await connection.execute('DELETE FROM users');
  await connection.execute('ALTER SEQUENCE users_id_seq RESTART WITH 1');

  print('   ✓ Deleted $before accounts');
  print('   ✓ Reset ID sequence to 1');
}

Future<void> _deleteByEmail(Connection connection, String email) async {
  print('[INFO] Deleting account: $email\n');

  final result = await connection.execute(
    'DELETE FROM users WHERE email = \$1',
    parameters: [email],
  );

  if (result > 0) {
    print('   ✓ Deleted 1 account ($email)');
  } else {
    print('   ⚠ No account found with email: $email');
  }
}

Future<void> _deleteUnverified(Connection connection) async {
  print('[INFO] Deleting unverified accounts...\n');

  // Show unverified before deletion
  final unverified = await connection.query<Map<String, dynamic>>(
    'SELECT id, email, username, created_at FROM users WHERE verified_at IS NULL ORDER BY created_at DESC',
  );

  if (unverified.isEmpty) {
    print('   ℹ No unverified accounts found');
    return;
  }

  print('   Found ${unverified.length} unverified account(s):');
  for (final user in unverified) {
    print('     • ${user['email']} (@${user['username']})');
  }

  // Delete
  final result = await connection.execute(
    'DELETE FROM users WHERE verified_at IS NULL',
  );

  print('\n   ✓ Deleted $result unverified account(s)');
}

Future<void> _showCount(Connection connection) async {
  final result = await connection.query<int>(
    'SELECT COUNT(*) FROM users',
  );
  final count = result.first.first ?? 0;

  print('[INFO] Current account count: $count\n');

  if (count > 0) {
    final verified = await connection.query<int>(
      'SELECT COUNT(*) FROM users WHERE verified_at IS NOT NULL',
    );
    final verifiedCount = verified.first.first ?? 0;
    final unverifiedCount = count - verifiedCount;

    print('   Verified:   $verifiedCount');
    print('   Unverified: $unverifiedCount');
  }
}

Future<void> _listAccounts(Connection connection) async {
  print('[INFO] Listing all accounts:\n');

  final users = await connection.query<Map<String, dynamic>>(
    '''SELECT id, email, username, verified_at, created_at 
       FROM users 
       ORDER BY created_at DESC''',
  );

  if (users.isEmpty) {
    print('   (no accounts)');
    return;
  }

  print('   ID  │ Email                    │ Username         │ Status       │ Created');
  print('   ────┼──────────────────────────┼──────────────────┼──────────────┼─────────────');

  for (final user in users) {
    final id = user['id'];
    final email = (user['email'] as String).padRight(24);
    final username = (user['username'] as String).padRight(16);
    final verified = user['verified_at'] != null ? 'Verified' : 'Pending';
    final created = user['created_at']?.toString().substring(0, 10) ?? '?';

    print('   $id   │ $email │ $username │ $verified │ $created');
  }
}

void _printUsage() {
  print('''
USAGE:
  dart run scripts/cleanup_accounts.dart <command> [options]

COMMANDS:
  all              Delete all accounts and reset ID sequence
  email <email>    Delete specific account by email
  unverified       Delete all unverified accounts only
  count            Show total account count
  list             List all accounts with details
  help             Show this help message

EXAMPLES:
  # Delete all test accounts
  dart run scripts/cleanup_accounts.dart all

  # Delete specific account
  dart run scripts/cleanup_accounts.dart email test@example.com

  # Delete all unverified accounts
  dart run scripts/cleanup_accounts.dart unverified

  # Check how many accounts exist
  dart run scripts/cleanup_accounts.dart count

  # See all accounts before cleanup
  dart run scripts/cleanup_accounts.dart list
''');
}
