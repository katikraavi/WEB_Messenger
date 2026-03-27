import 'package:test/test.dart';
import '../../lib/src/services/search_service.dart';
import '../../lib/src/models/message_search_result.dart';

void main() {
  group('SearchService (unit — no DB)', () {
    group('query sanitization', () {
      test('trims whitespace from query', () {
        final sanitized = SearchService.sanitizeQuery('  hello  ');
        expect(sanitized, equals('hello'));
      });

      test('lowercases query for case-insensitive matching', () {
        final sanitized = SearchService.sanitizeQuery('Hello World');
        expect(sanitized, equals('hello world'));
      });

      test('returns empty string for blank input', () {
        final sanitized = SearchService.sanitizeQuery('   ');
        expect(sanitized, equals(''));
      });

      test('rejects queries shorter than 2 characters', () {
        expect(SearchService.isQueryValid(''), isFalse);
        expect(SearchService.isQueryValid('a'), isFalse);
        expect(SearchService.isQueryValid('ab'), isTrue);
      });

      test('rejects queries longer than 200 characters', () {
        final longQuery = 'a' * 201;
        expect(SearchService.isQueryValid(longQuery), isFalse);
        expect(SearchService.isQueryValid('a' * 200), isTrue);
      });
    });

    group('MessageSearchResult model', () {
      test('creates from map', () {
        final now = DateTime.now();
        final result = MessageSearchResult.fromMap({
          'message_id': 'm1',
          'snippet': 'Hello world',
          'sent_at': now,
        });
        expect(result.messageId, equals('m1'));
        expect(result.snippet, equals('Hello world'));
        expect(result.sentAt, equals(now));
      });

      test('toMap round-trips all fields', () {
        final now = DateTime.now();
        final result = MessageSearchResult(
          messageId: 'm1',
          snippet: 'test',
          sentAt: now,
        );
        final map = result.toMap();
        expect(map['message_id'], equals('m1'));
        expect(map['snippet'], equals('test'));
        expect(map['sent_at'], equals(now));
      });
    });

    group('snippet extraction', () {
      test('extracts snippet centered on match', () {
        const content =
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
            'The quick brown fox jumps over the lazy dog.';
        final snippet =
            SearchService.extractSnippet(content: content, query: 'fox');
        expect(snippet, contains('fox'));
      });

      test('returns truncated snippet when content is long', () {
        final longContent = 'word ' * 200;
        final snippet =
            SearchService.extractSnippet(content: longContent, query: 'word');
        expect(snippet.length, lessThanOrEqualTo(200));
      });

      test('returns full content when shorter than max snippet length', () {
        const short = 'Hello world';
        final snippet =
            SearchService.extractSnippet(content: short, query: 'hello');
        expect(snippet, equals(short));
      });
    });
  });
}
