#!/usr/bin/env dart
import 'package:postgres/postgres.dart';
import 'dart:io';
import 'dart:async';

// Import migration runner
import '../lib/src/services/migration_runner.dart';

void main() async {
  final databaseUrl = Platform.environment['DATABASE_URL'] ??
      'postgres://messenger_user:messenger_password@localhost:5432/messenger_db';

  print('[INFO] Running database migrations...');
  print('[INFO] Database URL: ${_maskPassword(databaseUrl)}\n');

  try {
    // Parse database URL
    final uri = Uri.parse(databaseUrl);
    final connection = await Connection.open(
      Endpoint(
        host: uri.host,
        port: uri.port,
        database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'messenger_db',
        username: uri.userInfo.split(':').first,
        password: uri.userInfo.split(':').last,
      ),
      settings: ConnectionSettings(
        sslMode: SslMode.disable,
      ),
    );

    print('[✓] Connected to database\n');

    // Run migrations
    final runner = MigrationRunner(connection);
    await runner.runMigrations();

    print('\n[✓] All migrations completed successfully\n');

    // Display migration status
    final status = await runner.getMigrationStatus();
    print('Migration Status:');
    print('├─ Total migrations: ${status['total']}');
    print('├─ Applied: ${status['applied']}');
    print('└─ Pending: ${status['pending']}\n');

    print('Applied Migrations:');
    final migrations = status['migrations'] as List;
    for (final m in migrations) {
      if (m['status'] == 'APPLIED') {
        print('  ✓ v${m['version']}: ${m['description']}');
      }
    }

    await connection.close();
    print('\n[✓] Database connection closed');
    exit(0);
  } catch (e) {
    print('[ERROR] Migration failed: $e');
    exit(1);
  }
}

/// Mask password in database URL for logging
String _maskPassword(String url) {
  if (!url.contains('@')) return url;
  final parts = url.split('@');
  if (parts[0].contains(':')) {
    final userpass = parts[0].split(':');
    return '${userpass[0]}:***@${parts[1]}';
  }
  return url;
}
