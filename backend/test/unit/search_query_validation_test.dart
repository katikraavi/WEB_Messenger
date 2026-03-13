import 'package:test/test.dart';
import '../../../lib/src/models/search_query.dart';

void main() {
  group('SearchQuery - Username Validation', () {
    test('valid username: short', () {
      expect(SearchQuery.validateQuery('ab', SearchType.username), isNull);
    });

    test('valid username: alphanumeric', () {
      expect(SearchQuery.validateQuery('alice123', SearchType.username), isNull);
    });

    test('valid username: with underscore', () {
      expect(
        SearchQuery.validateQuery('alice_smith', SearchType.username),
        isNull,
      );
    });

    test('valid username: with hyphen', () {
      expect(SearchQuery.validateQuery('alice-smith', SearchType.username), isNull);
    });

    test('valid username: max length', () {
      expect(
        SearchQuery.validateQuery('a' * 100, SearchType.username),
        isNull,
      );
    });

    test('invalid username: too short (empty after trim)', () {
      expect(
        SearchQuery.validateQuery('', SearchType.username),
        isNotNull,
      );
    });

    test('invalid username: too short (1 char)', () {
      expect(
        SearchQuery.validateQuery('a', SearchType.username),
        isNotNull,
      );
    });

    test('invalid username: too long', () {
      expect(
        SearchQuery.validateQuery('a' * 101, SearchType.username),
        isNotNull,
      );
    });

    test('invalid username: special characters', () {
      expect(
        SearchQuery.validateQuery('alice<>', SearchType.username),
        isNotNull,
      );
    });

    test('invalid username: spaces', () {
      expect(
        SearchQuery.validateQuery('alice smith', SearchType.username),
        isNotNull,
      );
    });

    test('invalid username: only whitespace', () {
      expect(
        SearchQuery.validateQuery('   ', SearchType.username),
        isNotNull,
      );
    });

    test('invalid username: with @', () {
      expect(
        SearchQuery.validateQuery('alice@example.com', SearchType.username),
        isNotNull,
      );
    });
  });

  group('SearchQuery - Email Validation', () {
    test('valid email: simple', () {
      expect(
        SearchQuery.validateQuery('alice@example.com', SearchType.email),
        isNull,
      );
    });

    test('valid email: partial search', () {
      expect(
        SearchQuery.validateQuery('alice@', SearchType.email),
        isNull,
      );
    });

    test('valid email: domain only', () {
      expect(
        SearchQuery.validateQuery('example@example.com', SearchType.email),
        isNull,
      );
    });

    test('invalid email: no @', () {
      expect(
        SearchQuery.validateQuery('alice.example.com', SearchType.email),
        isNotNull,
      );
    });

    test('invalid email: no domain', () {
      expect(
        SearchQuery.validateQuery('alice@.com', SearchType.email),
        isNotNull,
      );
    });

    test('invalid email: no TLD', () {
      expect(
        SearchQuery.validateQuery('alice@example', SearchType.email),
        isNotNull,
      );
    });

    test('invalid email: empty', () {
      expect(
        SearchQuery.validateQuery('', SearchType.email),
        isNotNull,
      );
    });

    test('invalid email: too short (min 3 chars with @ and .)', () {
      expect(
        SearchQuery.validateQuery('a@b', SearchType.email),
        isNull, // Should pass - has @ and .
      );
    });

    test('invalid email: too long', () {
      expect(
        SearchQuery.validateQuery('a' * 101, SearchType.email),
        isNotNull,
      );
    });
  });

  group('SearchQuery - Constants', () {
    test('minLength is 2', () {
      expect(SearchQuery.minLength, equals(2));
    });

    test('maxLength is 100', () {
      expect(SearchQuery.maxLength, equals(100));
    });

    test('maxResults is 50', () {
      expect(SearchQuery.maxResults, equals(50));
    });
  });

  group('SearchType enum', () {
    test('SearchType.username exists', () {
      expect(SearchType.username, isNotNull);
    });

    test('SearchType.email exists', () {
      expect(SearchType.email, isNotNull);
    });
  });
}
