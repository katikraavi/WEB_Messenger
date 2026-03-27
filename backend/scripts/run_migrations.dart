#!/usr/bin/env dart

import 'package:postgres/postgres.dart';
import 'dart:io';
import 'dart:async';

// Import migration runner
import '../lib/src/database/database_connection_config.dart';
import '../lib/src/services/migration_runner.dart';

void main() async {
  final databaseConfig = DatabaseConnectionConfig.fromEnvironment(
    Platform.environment,
  );

  print('[INFO] Running database migrations...');
  print('[INFO] Database target: ${databaseConfig.maskedDescription}');
  print(
    '[INFO] SSL mode: ${databaseConfig.requireSsl ? 'require' : 'disable'}\n',
  );

  try {
    final connection = await Connection.open(
      Endpoint(
        host: databaseConfig.host,
        port: databaseConfig.port,
        database: databaseConfig.database,
        username: databaseConfig.username,
        password: databaseConfig.password,
      ),
      settings: ConnectionSettings(
        sslMode: databaseConfig.requireSsl ? SslMode.require : SslMode.disable,
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
