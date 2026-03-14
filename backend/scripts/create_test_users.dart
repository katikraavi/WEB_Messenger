#!/usr/bin/env dart

import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

/// Test Users Creation Script
/// 
/// Creates predefined test users in the database:
/// - alice@example.com / alice123
/// - bob@example.com / bob123
/// - charlie@example.com / charlie123
/// - diane@test.org / diane123

void main() async {
  print('╔════════════════════════════════════════════════════════╗');
  print('║ Creating Test Users in Database                       ║');
  print('╚════════════════════════════════════════════════════════╝');
  print('');

  // Database connection parameters
  final host = Platform.environment['DATABASE_HOST'] ?? 'localhost';
  final port = int.parse(Platform.environment['DATABASE_PORT'] ?? '5432');
  final database = Platform.environment['DATABASE_NAME'] ?? 'messenger_db';
  final username = Platform.environment['DATABASE_USER'] ?? 'messenger_user';
  final password = Platform.environment['DATABASE_PASSWORD'] ?? 'messenger_password';

  print('[INFO] Connecting to database...');
  print('       Host: $host:$port');
  print('       Database: $database');
  print('');

  late PostgreSQLConnection connection;
  try {
    connection = PostgreSQLConnection(
      host,
      port,
      database,
      username: username,
      password: password,
    );
    await connection.open();
    print('[✓] Connected to database');
  } catch (e) {
    print('[✗] Failed to connect: $e');
    exit(1);
  }

  try {
    // Test users to create
    final testUsers = [
      {
        'username': 'alice',
        'email': 'alice@example.com',
        'password': 'alice123',
        'full_name': 'Alice Anderson',
      },
      {
        'username': 'bob',
        'email': 'bob@example.com',
        'password': 'bob123',
        'full_name': 'Bob Baker',
      },
      {
        'username': 'charlie',
        'email': 'charlie@example.com',
        'password': 'charlie123',
        'full_name': 'Charlie Chen',
      },
      {
        'username': 'diane',
        'email': 'diane@test.org',
        'password': 'diane123',
        'full_name': 'Diane Davis',
      },
    ];

    int createdCount = 0;
    int skippedCount = 0;

    for (final user in testUsers) {
      final username = user['username'] as String;
      final email = user['email'] as String;
      final password = user['password'] as String;
      final fullName = user['full_name'] as String;

      print('\n[...] Processing @$username ($email)...');

      // Check if user already exists
      final existing = await connection.query(
        'SELECT id FROM "users" WHERE email = @email OR username = @username',
        substitutionValues: {
          'email': email,
          'username': username,
        },
      );

      if (existing.isNotEmpty) {
        print('     [⊘] Already exists, skipping');
        skippedCount++;
        continue;
      }

      try {
        final userId = const Uuid().v4();
        final passwordHash = _hashPassword(password);
        final now = DateTime.now().toUtc();

        // Insert user
        await connection.execute(
          '''INSERT INTO "users" (id, email, username, password_hash, email_verified, created_at)
             VALUES (@id, @email, @username, @password_hash, @email_verified, @created_at)''',
          substitutionValues: {
            'id': userId,
            'email': email.toLowerCase(),
            'username': username,
            'password_hash': passwordHash,
            'email_verified': true, // Mark as verified for test users
            'created_at': now,
          },
        );

        print('     [✓] Created user: $userId');

        // Create profile for the user
        try {
          await connection.execute(
            '''INSERT INTO "user_profiles" (user_id, full_name, bio, profile_picture_url, is_private_profile, created_at, updated_at)
               VALUES (@user_id, @full_name, @bio, @profile_picture_url, @is_private_profile, @created_at, @updated_at)''',
            substitutionValues: {
              'user_id': userId,
              'full_name': fullName,
              'bio': 'Test user - $fullName',
              'profile_picture_url': null,
              'is_private_profile': false,
              'created_at': now,
              'updated_at': now,
            },
          );
          print('     [✓] Created profile for @$username');
        } catch (e) {
          print('     [⚠] Could not create profile: $e');
        }

        createdCount++;
      } catch (e) {
        print('     [✗] Error creating user: $e');
      }
    }

    print('\n╔════════════════════════════════════════════════════════╗');
    print('║ Summary                                              ║');
    print('╚════════════════════════════════════════════════════════╝');
    print('[✓] Created: $createdCount test users');
    print('[⊘] Skipped: $skippedCount (already exist)');
    print('');
    print('Test Users Ready:');
    print('  • alice / alice123');
    print('  • bob / bob123');
    print('  • charlie / charlie123');
    print('  • diane / diane123');
    print('');
    print('All test users have email_verified=true');
    print('');
  } catch (e) {
    print('[✗] Error: $e');
    exit(1);
  } finally {
    await connection.close();
  }
}

/// Simple password hash function (matches server.dart implementation)
String _hashPassword(String password) {
  return password.hashCode.toRadixString(36);
}
