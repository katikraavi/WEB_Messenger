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
/// - testuser1@example.com / testuser1pass
/// - testuser2@example.com / testuser2pass

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
      {
        'username': 'testuser1',
        'email': 'testuser1@example.com',
        'password': 'testuser1pass',
        'full_name': 'Test User One',
      },
      {
        'username': 'testuser2',
        'email': 'testuser2@example.com',
        'password': 'testuser2pass',
        'full_name': 'Test User Two',
      },
    ];

    int createdCount = 0;
    int updatedCount = 0;
    final seededUserIds = <String, String>{};

    for (final user in testUsers) {
      final username = user['username'] as String;
      final email = user['email'] as String;
      final password = user['password'] as String;
      final fullName = user['full_name'] as String;
      final normalizedEmail = email.toLowerCase();
      final passwordHash = _hashPassword(password);
      final now = DateTime.now().toUtc();

      print('\n[...] Processing @$username ($email)...');

      // Check if user already exists
      final existing = await connection.query(
        'SELECT id FROM "users" WHERE email = @email OR username = @username',
        substitutionValues: {
          'email': normalizedEmail,
          'username': username,
        },
      );

      if (existing.isNotEmpty) {
        final userId = existing.first[0] as String;
        seededUserIds[username] = userId;
        await connection.execute(
          '''UPDATE "users"
             SET email = @email,
                 username = @username,
                 password_hash = @password_hash,
                 email_verified = @email_verified
             WHERE id = @id''',
          substitutionValues: {
            'id': userId,
            'email': normalizedEmail,
            'username': username,
            'password_hash': passwordHash,
            'email_verified': true,
          },
        );

        print('     [↻] Updated existing user credentials');
        updatedCount++;
        continue;
      }

      try {
        final userId = const Uuid().v4();

        // Insert user
        await connection.execute(
          '''INSERT INTO "users" (id, email, username, password_hash, email_verified, created_at)
             VALUES (@id, @email, @username, @password_hash, @email_verified, @created_at)''',
          substitutionValues: {
            'id': userId,
            'email': normalizedEmail,
            'username': username,
            'password_hash': passwordHash,
            'email_verified': true, // Mark as verified for test users
            'created_at': now,
          },
        );

        print('     [✓] Created user: $userId');
        seededUserIds[username] = userId;

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

    final testUser1Id = seededUserIds['testuser1'];
    final testUser2Id = seededUserIds['testuser2'];
    if (testUser1Id != null && testUser2Id != null) {
      final participantIds = [testUser1Id, testUser2Id]..sort();
      await connection.execute(
        '''INSERT INTO "chats" (
             id,
             participant_1_id,
             participant_2_id,
             is_participant_1_archived,
             is_participant_2_archived,
             created_at,
             updated_at
           )
           VALUES (@id, @participant1, @participant2, false, false, @now, @now)
           ON CONFLICT (participant_1_id, participant_2_id)
           DO UPDATE SET updated_at = @now''',
        substitutionValues: {
          'id': const Uuid().v4(),
          'participant1': participantIds[0],
          'participant2': participantIds[1],
          'now': DateTime.now().toUtc(),
        },
      );
      print('     [✓] Ensured seeded chat between testuser1 and testuser2');
    }

    print('\n╔════════════════════════════════════════════════════════╗');
    print('║ Summary                                              ║');
    print('╚════════════════════════════════════════════════════════╝');
    print('[✓] Created: $createdCount test users');
    print('[↻] Updated: $updatedCount existing users');
    print('');
    print('Test Users Ready:');
    print('  • alice / alice123');
    print('  • bob / bob123');
    print('  • charlie / charlie123');
    print('  • diane / diane123');
    print('  • testuser1 / testuser1pass');
    print('  • testuser2 / testuser2pass');
    print('');
    print('All test users have email_verified=true');
    print('Seeded chat ready for: testuser1 <-> testuser2');
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
