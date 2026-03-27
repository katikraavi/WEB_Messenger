import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/models/auth_models.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/chats/models/chat_model.dart';
import 'package:frontend/features/chats/providers/active_chats_provider.dart';
import 'package:frontend/features/chats/providers/user_profile_provider.dart';
import 'package:frontend/features/chats/screens/chat_list_screen.dart';
import 'package:frontend/features/chats/widgets/chat_list_tile_consumer.dart';
import 'package:frontend/features/profile/models/user_profile.dart';
import 'package:provider/provider.dart' as provider_pkg;

class _FakeAuthProvider extends AuthProvider {
  final User _fakeUser;
  final String _fakeToken;

  _FakeAuthProvider({required User user, required String token})
      : _fakeUser = user,
        _fakeToken = token;

  @override
  User? get user => _fakeUser;

  @override
  String? get token => _fakeToken;
}

void main() {
  group('Chat List Feature Integration Tests (T027)', () {
    late _FakeAuthProvider fakeAuth;

    setUp(() {
      fakeAuth = _FakeAuthProvider(
        user: User(
          userId: 'user-alice',
          email: 'alice@example.com',
          username: 'alice',
        ),
        token: 'test-token',
      );
    });

    List<Chat> createMockChats() {
      final now = DateTime.now();
      return [
        Chat(
          id: 'chat-1',
          participant1Id: 'user-alice',
          participant2Id: 'user-bob',
          isParticipant1Archived: false,
          isParticipant2Archived: false,
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now.subtract(const Duration(hours: 2)),
          lastMessagePreview: 'Hey there',
          lastMessageTimestamp: now.subtract(const Duration(hours: 2)),
        ),
        Chat(
          id: 'chat-2',
          participant1Id: 'user-alice',
          participant2Id: 'user-charlie',
          isParticipant1Archived: false,
          isParticipant2Archived: false,
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now.subtract(const Duration(days: 1)),
          lastMessagePreview: 'Older message',
          lastMessageTimestamp: now.subtract(const Duration(days: 1)),
        ),
      ];
    }

    Widget buildTestApp({
      required List<Override> overrides,
    }) {
      return provider_pkg.ChangeNotifierProvider<AuthProvider>.value(
        value: fakeAuth,
        child: ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: Scaffold(
              body: ChatListScreen(),
            ),
          ),
        ),
      );
    }

    testWidgets('Chat list screen loads and displays chat tiles',
        (WidgetTester tester) async {
      final mockChats = createMockChats();

      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            activeChatListProvider.overrideWith(
              (ref, token) => Stream<List<Chat>>.value(mockChats),
            ),
            userProfileProvider.overrideWith(
              (ref, params) => Future<UserProfile>.value(
                UserProfile(
                  userId: params.$1,
                  username: params.$1 == 'user-bob' ? 'Bob' : 'Charlie',
                ),
              ),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ChatListScreen), findsOneWidget);
      expect(find.byType(ChatListTileConsumer), findsNWidgets(2));
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('Empty state displayed when there are no chats',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            activeChatListProvider.overrideWith(
              (ref, token) => Stream<List<Chat>>.value(const []),
            ),
            userProfileProvider.overrideWith(
              (ref, params) => Future<UserProfile>.value(
                UserProfile(userId: params.$1, username: 'User'),
              ),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.text('No active chats'), findsOneWidget);
    });

    testWidgets('Error state displayed on active chats stream error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            activeChatListProvider.overrideWith(
              (ref, token) => Stream<List<Chat>>.error(Exception('Network error')),
            ),
            userProfileProvider.overrideWith(
              (ref, params) => Future<UserProfile>.value(
                UserProfile(userId: params.$1, username: 'User'),
              ),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Failed to load chats'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

  });
}
