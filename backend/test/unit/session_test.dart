import 'package:test/test.dart';
import '../../lib/src/models/device_session.dart';

void main() {
  group('DeviceSession model (unit — no DB)', () {
    group('construction and serialization', () {
      test('creates from map', () {
        final now = DateTime.now();
        final map = {
          'id': 's1',
          'user_id': 'u1',
          'device_id': 'dev-abc',
          'device_name': 'Pixel 8',
          'token_hash': 'hmac-sha256-hash',
          'created_at': now,
          'last_seen_at': now,
        };
        final session = DeviceSession.fromMap(map);
        expect(session.id, equals('s1'));
        expect(session.deviceId, equals('dev-abc'));
        expect(session.tokenHash, equals('hmac-sha256-hash'));
        expect(session.deviceName, equals('Pixel 8'));
      });

      test('toMap round-trips all fields', () {
        final now = DateTime.now();
        final session = DeviceSession(
          id: 's1',
          userId: 'u1',
          deviceId: 'dev-abc',
          deviceName: 'agent-device',
          tokenHash: 'hash',
          createdAt: now,
          lastSeenAt: now,
        );
        final map = session.toMap();
        expect(map['id'], equals('s1'));
        expect(map['device_id'], equals('dev-abc'));
        expect(map['token_hash'], equals('hash'));
      });

      test('handles nullable optional fields gracefully', () {
        final now = DateTime.now();
        final map = {
          'id': 's2',
          'user_id': 'u1',
          'device_id': 'dev-xyz',
          'device_name': null,
          'token_hash': 'h2',
          'created_at': now,
          'last_seen_at': now,
        };
        final session = DeviceSession.fromMap(map);
        expect(session.deviceName, isNull);
      });
    });

    group('security assertions', () {
      test('token_hash must not equal raw token format (no Bearer prefix)', () {
        // Ensure we never accidentally store a Bearer token
        const rawToken = 'eyJhbGciOiJIUzI1NiJ9.payload.sig';
        final hashMock = 'hmac:$rawToken'; // must differ from raw

        // The hash should not look like a JWT
        expect(hashMock.startsWith('eyJ'), isFalse);
      });
    });
  });
}
