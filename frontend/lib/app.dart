import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:firebase_core/firebase_core.dart';
import 'package:frontend/core/notifications/app_feedback_service.dart';
import 'package:frontend/core/services/app_exception_logger.dart';
import 'package:frontend/core/services/api_client.dart';
import 'package:frontend/core/push_notifications/push_notification_handler.dart';
import 'package:frontend/core/notifications/local_notification_service.dart';
import 'package:frontend/features/auth/models/auth_models.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/auth_flow_screen.dart';
import 'package:frontend/features/search/screens/search_screen.dart';
import 'package:frontend/features/profile/screens/profile_view_screen.dart';
import 'package:frontend/features/invitations/screens/invitations_screen.dart';
import 'package:frontend/features/invitations/providers/invites_provider.dart';
import 'package:frontend/features/chats/screens/chat_list_screen.dart';
import 'package:frontend/features/chats/screens/create_group_screen.dart';
import 'package:frontend/features/chats/screens/search_groups_screen.dart';
import 'package:frontend/features/chats/providers/active_chats_provider.dart';
import 'package:frontend/features/chats/providers/chats_provider.dart';
import 'package:frontend/features/chats/providers/chat_cache_invalidator.dart';
import 'package:frontend/features/chats/providers/websocket_provider.dart';
import 'package:frontend/features/chats/services/message_websocket_service.dart';
import 'package:frontend/features/chats/services/chat_notification_settings_service.dart';
import 'package:flutter/foundation.dart';

String _displayName(String? value) {
  if (value == null || value.isEmpty) {
    return '';
  }

  return value[0].toUpperCase() + value.substring(1);
}

class _DevTestUser {
  final String label;
  final String email;
  final String password;

  const _DevTestUser({
    required this.label,
    required this.email,
    required this.password,
  });

  LoginRequest get loginRequest =>
      LoginRequest(email: email, password: password);
}

const List<_DevTestUser> _devTestUsers = [
  _DevTestUser(
    label: 'Alice',
    email: 'alice@example.com',
    password: 'alice123',
  ),
  _DevTestUser(label: 'Bob', email: 'bob@example.com', password: 'bob123'),
  _DevTestUser(
    label: 'Charlie',
    email: 'charlie@example.com',
    password: 'charlie123',
  ),
  _DevTestUser(label: 'Diane', email: 'diane@test.org', password: 'diane123'),
  _DevTestUser(
    label: 'TestUser1',
    email: 'testuser1@example.com',
    password: 'testuser1pass',
  ),
  _DevTestUser(
    label: 'TestUser2',
    email: 'testuser2@example.com',
    password: 'testuser2pass',
  ),
];

/// Root widget for Mobile Messenger application
///
/// Responsible for:
/// - Setting up Material Design theme
/// - Configuring app navigation
/// - Handling backend connection status
/// - Displaying appropriate UI based on connection state

class MessengerApp extends StatefulWidget {
  const MessengerApp({super.key});

  @override
  State<MessengerApp> createState() => _MessengerAppState();
}

class _MessengerAppState extends State<MessengerApp> {
  bool _isConnected = false;
  bool _isInitializing = true;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initializeBackendConnection();
    _initializePushNotifications();
  }

  /// Initialize local and remote notification handling.
  Future<void> _initializePushNotifications() async {
    try {
      await LocalNotificationService.instance.initialize(
        onPayloadTap: _handleNotificationPayload,
      );

      if (Firebase.apps.isEmpty) {
        return;
      }

      await PushNotificationHandler().initialize(navigatorKey: _navigatorKey);
    } catch (e) {
      AppExceptionLogger.log(
        e,
        context: 'MessengerApp._initializePushNotifications',
      );
      AppFeedbackService.showWarning(
        'Push notifications are unavailable. Messenger continues without them.',
      );
    }
  }

  void _handleNotificationPayload(Map<String, dynamic> payload) {
    final type = payload['type'] as String?;
    if (type == 'chat_invite') {
      _navigatorKey.currentState?.pushNamed('/invitations');
    }
  }

  /// Wait for backend connection to be established
  Future<void> _initializeBackendConnection() async {
    // Give the API client initialization from main() a moment to complete
    await Future.delayed(const Duration(milliseconds: 500));

    // Initialize auth provider - restore session if token exists
    if (mounted) {
      await context.read<AuthProvider>().initialize();
    }

    setState(() {
      _isConnected = ApiClient.isConnected;
      _isInitializing = false;
    });
  }

  Future<void> _retryBackendConnection() async {
    setState(() {
      _isInitializing = true;
    });

    final isConnected = await ApiClient.connectToBackend();

    if (!mounted) {
      return;
    }

    setState(() {
      _isConnected = isConnected;
      _isInitializing = false;
    });

    if (!isConnected) {
      AppFeedbackService.showError(
        'Still unable to reach the backend. Messenger remains on the last stable screen.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: AppFeedbackService.scaffoldMessengerKey,
      title: 'Mobile Messenger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          insetPadding: EdgeInsets.fromLTRB(16, 12, 16, 88),
          dismissDirection: DismissDirection.horizontal,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          insetPadding: EdgeInsets.fromLTRB(16, 12, 16, 88),
          dismissDirection: DismissDirection.horizontal,
        ),
      ),
      themeMode: ThemeMode.system,
      routes: {'/invitations': (context) => const InvitationsScreen()},
      home: _buildHome(),
    );
  }

  /// Build home screen based on connection status
  Widget _buildHome() {
    if (_isInitializing) {
      return const _LoadingScreen();
    }

    if (!_isConnected) {
      return _ConnectionErrorScreen(onRetry: _retryBackendConnection);
    }

    return const _HomeScreen();
  }
}

/// Loading screen shown while app initializes
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Initializing Mobile Messenger',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Connecting to backend...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen shown if backend connection fails
class _ConnectionErrorScreen extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ConnectionErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Connection Failed',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Unable to connect to backend server. Please check that docker-compose is running and try restarting the app.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Home screen placeholder
class _HomeScreen extends riverpod.ConsumerStatefulWidget {
  const _HomeScreen();

  @override
  riverpod.ConsumerState<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends riverpod.ConsumerState<_HomeScreen> {
  String? _connectedRealtimeUserId;
  riverpod.ProviderSubscription<riverpod.AsyncValue<WebSocketEvent>>?
  _messageEventSubscription;

  @override
  void initState() {
    super.initState();
    _messageEventSubscription = ref.listenManual(messageEventStreamProvider, (
      previous,
      next,
    ) {
      next.whenData((event) async {
        final authProvider = context.read<AuthProvider>();
        try {
          await _handleRealtimeEvent(event, authProvider);
        } catch (e, st) {
          AppExceptionLogger.log(
            e,
            stackTrace: st,
            context: 'HomeScreen.messageEventListener',
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _messageEventSubscription?.close();
    _disconnectRealtime();
    super.dispose();
  }

  Future<void> _ensureRealtimeConnected(AuthProvider authProvider) async {
    final token = authProvider.token;
    final userId = authProvider.user?.userId;
    if (token == null || userId == null) {
      return;
    }

    if (_connectedRealtimeUserId == userId) {
      return;
    }

    try {
      await ref
          .read(messageWebSocketProvider.notifier)
          .connect(token: token, userId: userId);
      await ChatNotificationSettingsService.instance.syncMutedChats(token);
      await ChatNotificationSettingsService.instance.tryRegisterFcmToken(
        token: token,
      );
      _connectedRealtimeUserId = userId;
    } catch (e) {
      AppExceptionLogger.log(e, context: 'HomeScreen._ensureRealtimeConnected');
      await _disconnectRealtime();
      AppFeedbackService.showWarning(
        'Realtime sync is unavailable. Messenger restored the last synced state.',
      );
    }
  }

  Future<void> _disconnectRealtime() async {
    if (_connectedRealtimeUserId == null) {
      return;
    }

    await ref.read(messageWebSocketProvider.notifier).disconnect();
    _connectedRealtimeUserId = null;
  }

  Future<void> _handleRealtimeEvent(
    WebSocketEvent event,
    AuthProvider authProvider,
  ) async {
    try {
      final currentUserId = authProvider.user?.userId;
      if (event.type == WebSocketEventType.messageCreated) {
        final senderId = event.data['sender_id'] as String?;
        if (senderId == null || senderId == currentUserId) {
          return;
        }

        final chatId =
            (event.data['chatId'] ?? event.data['chat_id']) as String?;
        if (chatId == null ||
            ChatNotificationSettingsService.instance.isMutedLocally(chatId)) {
          return;
        }

        final mediaType = event.data['media_type'] as String?;
        final title = event.data['sender_username'] as String? ?? 'New message';
        var body = 'New message';
        if (mediaType != null) {
          if (mediaType.startsWith('image/')) {
            body = '[Image]';
          } else if (mediaType.startsWith('video/')) {
            body = '[Video]';
          } else if (mediaType.startsWith('audio/')) {
            body = '[Audio message]';
          }
        } else {
          final encryptedContent = event.data['encrypted_content'] as String?;
          if (encryptedContent != null && encryptedContent.isNotEmpty) {
            try {
              body = utf8.decode(base64Decode(encryptedContent));
            } catch (_) {
              body = 'New message';
            }
          }
        }

        await LocalNotificationService.instance.showMessageNotification(
          chatId: chatId,
          title: title,
          body: body,
        );
        return;
      }

      if (event.type == WebSocketEventType.invitationSent) {
        final inviteId = event.data['inviteId'] as String? ?? '';
        final senderName = event.data['senderName'] as String? ?? 'Someone';
        await LocalNotificationService.instance.showInviteNotification(
          inviteId: inviteId,
          title: 'Chat invite',
          body: '$senderName sent you a chat invite',
        );
        ref.invalidate(pendingInvitesProvider);
        ref.invalidate(pendingInviteCountProvider);
        ref.invalidate(pendingGroupInvitesProvider);
        ref.invalidate(pendingGroupInviteCountProvider);
        return;
      }

      if (event.type == WebSocketEventType.invitationAccepted ||
          event.type == WebSocketEventType.invitationDeclined ||
          event.type == WebSocketEventType.invitationCancelled) {
        final inviteId =
            (event.data['inviteId'] ?? event.data['id']) as String?;
        if (inviteId != null && inviteId.isNotEmpty) {
          await LocalNotificationService.instance.dismissInviteNotification(
            inviteId,
          );
        }
        ref.invalidate(pendingInvitesProvider);
        ref.invalidate(pendingInviteCountProvider);
        ref.invalidate(pendingGroupInvitesProvider);
        ref.invalidate(pendingGroupInviteCountProvider);
      }
    } catch (e, st) {
      AppExceptionLogger.log(
        e,
        stackTrace: st,
        context: 'HomeScreen._handleRealtimeEvent',
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _disconnectRealtime();
          });
          return AuthFlowScreen(
            onAuthSuccess: () {
              // Invalidate invite cache because a new user just logged in
              ref.read(invitesCacheInvalidatorProvider.notifier).state++;
              // Invalidate chat cache on login (T025)
              ref.read(chatsCacheInvalidatorProvider.notifier).state++;
            },
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureRealtimeConnected(authProvider);
        });

        // Show main app if authenticated
        return _AuthenticatedHomeScreen(
          user: authProvider.user!,
          authProvider: authProvider,
        );
      },
    );
  }
}

/// Authenticated home screen with bottom navigation
class _AuthenticatedHomeScreen extends riverpod.ConsumerStatefulWidget {
  final User user;
  final AuthProvider authProvider;

  const _AuthenticatedHomeScreen({
    required this.user,
    required this.authProvider,
  });

  @override
  riverpod.ConsumerState<_AuthenticatedHomeScreen> createState() =>
      _AuthenticatedHomeScreenState();
}

class _AuthenticatedHomeScreenState
    extends riverpod.ConsumerState<_AuthenticatedHomeScreen> {
  int _selectedIndex = 1; // Start at Chats tab, skip Search page

  bool _useWebSidebar(BuildContext context) {
    return kIsWeb && MediaQuery.sizeOf(context).width >= 1100;
  }

  String _pageTitle() {
    return _selectedIndex == 1
        ? 'Chats'
        : _selectedIndex == 2
        ? 'Invitations'
        : _selectedIndex == 3
        ? 'My Profile'
        : 'Search Users';
  }

  Widget _buildShellBody() {
    final body = _buildBody();
    if (!kIsWeb) {
      return body;
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF2FF), Color(0xFFF8FBFF)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: body,
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      ref.read(chatsCacheInvalidatorProvider.notifier).state++;
    }
  }

  Future<void> _logout() async {
    await ref.read(messageWebSocketProvider.notifier).disconnect();
    await widget.authProvider.logout();
    ref.read(invitesCacheInvalidatorProvider.notifier).state++;
  }

  Future<void> _openCreateGroup(BuildContext context) async {
    final createdGroupId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );

    if (!context.mounted || createdGroupId == null) {
      return;
    }

    final token = widget.authProvider.token;
    if (token != null && token.isNotEmpty) {
      ref.invalidate(chatsProvider(token));
      ref.invalidate(activeChatListProvider(token));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Group created: $createdGroupId'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _switchToDevUser(_DevTestUser user) async {
    try {
      await ref.read(messageWebSocketProvider.notifier).disconnect();
      await widget.authProvider.logout();
      await widget.authProvider.login(user.loginRequest);
      ref.read(invitesCacheInvalidatorProvider.notifier).state++;
      ref.read(chatsCacheInvalidatorProvider.notifier).state++;
      if (!mounted) {
        return;
      }
      AppFeedbackService.showInfo('Switched to ${user.label}.');
    } catch (e, st) {
      AppExceptionLogger.log(
        e,
        stackTrace: st,
        context: 'AuthenticatedHomeScreen._switchToDevUser',
      );
      if (!mounted) {
        return;
      }
      AppFeedbackService.showError('Failed to switch to ${user.label}.');
    }
  }

  Widget _buildSidebarNavItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F0FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF1D4ED8) : Colors.blueGrey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF1D4ED8) : Colors.blueGrey,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDevSwitcher() {
    if (kReleaseMode) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E4FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.science_outlined,
                size: 16,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Dev Test Users',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _devTestUsers
                .map(
                  (user) => ActionChip(
                    label: Text(user.label),
                    onPressed: widget.authProvider.isLoading
                        ? null
                        : () => _switchToDevUser(user),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSidebar(BuildContext context, int pendingCount) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE1EAF7)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.forum_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Messenger',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _displayName(widget.user.username),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildSidebarNavItem(
            icon: Icons.chat_bubble_outline,
            label: 'Chats',
            selected: _selectedIndex == 1,
            onTap: () => _selectTab(1),
          ),
          _buildSidebarNavItem(
            icon: Icons.mail_outline,
            label: 'Invitations',
            selected: _selectedIndex == 2,
            onTap: () => _selectTab(2),
            trailing: pendingCount > 0
                ? Badge(label: Text(pendingCount.toString()))
                : null,
          ),
          _buildSidebarNavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            selected: _selectedIndex == 3,
            onTap: () => _selectTab(3),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
            },
            icon: const Icon(Icons.person_search_outlined),
            label: const Text('Search Users'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _openCreateGroup(context),
            icon: const Icon(Icons.group_add),
            label: const Text('Create Group'),
          ),
          const SizedBox(height: 18),
          _buildDevSwitcher(),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: widget.authProvider.isLoading ? null : _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSidebarLayout(BuildContext context, int pendingCount) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF2FF), Color(0xFFF8FBFF)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWebSidebar(context, pendingCount),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE1EAF7)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: _buildBody(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch combined pending invites (direct + group) for badge.
    final pendingCount = ref.watch(totalPendingInviteCountProvider);
    final useWebSidebar = _useWebSidebar(context);

    return Scaffold(
      extendBody: kIsWeb && !useWebSidebar,
      appBar: AppBar(
        titleSpacing: kIsWeb ? 24 : null,
        title: Row(
          children: [
            if (kIsWeb)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            if (kIsWeb) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_pageTitle()),
                  Text(
                    'Signed in as ${_displayName(widget.user.username)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blue[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: kIsWeb ? const Color(0xFFF8FBFF) : null,
        actions: [
          if (!useWebSidebar && _selectedIndex == 1)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search Groups',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchGroupsScreen()),
                );
              },
            ),
          if (!useWebSidebar && _selectedIndex == 1)
            IconButton(
              icon: const Icon(Icons.group_add),
              tooltip: 'Create Group Chat',
              onPressed: () => _openCreateGroup(context),
            ),
          if (!useWebSidebar)
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: useWebSidebar
          ? _buildWebSidebarLayout(context, pendingCount)
          : _buildShellBody(),
      bottomNavigationBar: useWebSidebar
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(
                kIsWeb ? 24 : 0,
                0,
                kIsWeb ? 24 : 0,
                kIsWeb ? 18 : 0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kIsWeb ? 22 : 0),
                child: BottomNavigationBar(
                  currentIndex: _selectedIndex - 1,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: kIsWeb ? Colors.white : null,
                  selectedItemColor: const Color(0xFF1D4ED8),
                  unselectedItemColor: Colors.blueGrey,
                  elevation: kIsWeb ? 10 : 8,
                  items: <BottomNavigationBarItem>[
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.chat_bubble_outline),
                      label: 'Chats',
                    ),
                    BottomNavigationBarItem(
                      icon: Badge(
                        isLabelVisible: pendingCount > 0,
                        label: Text(pendingCount.toString()),
                        child: const Icon(Icons.mail_outline),
                      ),
                      label: 'Invitations',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline),
                      label: 'Profile',
                    ),
                  ],
                  onTap: (index) {
                    _selectTab(index + 1);
                  },
                ),
              ),
            ),
    );
  }

  /// Build body based on selected tab
  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        // Index 0: Search Tab (now unused, kept for app stability)
        _SearchTab(user: widget.user),

        // Index 1: Chat List Tab (T024) - Now the default
        const ChatListScreen(),

        // Index 2: Invitations Tab
        const InvitationsScreen(),

        // Index 3: Profile Tab - Show user's own profile with pre-loaded data
        ProfileViewScreen(userId: widget.user.userId, isOwnProfile: true),
      ],
    );
  }
}

/// Search tab content
class _SearchTab extends StatelessWidget {
  final User user;

  const _SearchTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'Welcome, ${_displayName(user.username)}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              const Text(
                'Status: Connected',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Backend URL: ${ApiClient.getBaseUrl()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),

              // Main Search Button - PROMINENT
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_search,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Search Users',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Test Info Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Ready to Chat!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Use the search feature to find other users and send them invitations to chat!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
