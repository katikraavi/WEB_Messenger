import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart' as provider;
import 'package:frontend/core/notifications/app_feedback_service.dart';
import 'package:frontend/core/services/app_exception_logger.dart';
import '../models/user_profile.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/profile_picture_widget.dart';
import 'profile_edit_screen.dart';
import '../../invitations/services/invite_api_service.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileViewScreen extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const ProfileViewScreen({
    required this.userId,
    this.isOwnProfile = false,
    super.key,
  });

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  late InviteApiService _inviteService;
  bool _isLoadingInvite = false;
  String? _inviteError;
  bool _missingAuthProviderWarningShown = false;

  @override
  void initState() {
    super.initState();
    _inviteService = InviteApiService(baseUrl: 'http://localhost:8081');
  }

  Future<void> _sendInvite() async {
    setState(() {
      _isLoadingInvite = true;
      _inviteError = null;
    });

    try {
      await _inviteService.sendInvite(widget.userId);
      if (mounted) {
        AppFeedbackService.showInfo('Invitation sent.');
      }
    } catch (e) {
      AppExceptionLogger.log(e, context: 'ProfileViewScreen._sendInvite');
      setState(() {
        _inviteError = e.toString();
      });
      if (mounted) {
        AppFeedbackService.showError(
          'Could not send invitation. Messenger kept the current profile view.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInvite = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final token = _readTokenSafely(context);
        final profileAsync = token == null
            ? ref.watch(userProfileProvider(widget.userId))
            : ref.watch(userProfileWithTokenProvider((widget.userId, token)));

        return profileAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: _buildLoadingSkeleton(context),
          ),
          error: (error, stackTrace) => Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: _buildErrorState(context, ref, error.toString(), token),
          ),
          data: (profile) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Profile'),
                actions: [
                  if (widget.isOwnProfile)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileEditScreen(profile: profile),
                          ),
                        );
                      },
                    ),
                ],
              ),
              body: _buildProfileContent(context, ref, profile, token),
            );
          },
        );
      },
    );
  }

  String? _readTokenSafely(BuildContext context) {
    final authProvider = provider.Provider.of<AuthProvider?>(
      context,
      listen: false,
    );

    if (authProvider == null && !_missingAuthProviderWarningShown) {
      _missingAuthProviderWarningShown = true;
      AppExceptionLogger.log(
        StateError('AuthProvider not found in context'),
        context: 'ProfileViewScreen._readTokenSafely',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppFeedbackService.showWarning(
          'Limited profile mode is active. Some authenticated profile actions are unavailable.',
        );
      });
    }

    return authProvider?.token;
  }

  /// Build loading skeleton with shimmer effect
  Widget _buildLoadingSkeleton(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // ignore: unused_result
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile picture skeleton
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 16),

            // Username skeleton
            Container(
              width: 150,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),

            // Privacy badge skeleton
            Container(
              width: 100,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 24),

            // Bio skeleton
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error state with retry button
  Widget _buildErrorState(
    BuildContext context,
    WidgetRef ref,
    String errorMsg,
    String? token,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshProfile(ref, token);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Unable to Load Profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  errorMsg,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    _refreshProfile(ref, token);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build profile content with all UI elements
  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    String? token,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshProfile(ref, token);
        // Wait a bit for the refresh to show
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // T037: Profile Picture Widget (circular with network image)
            ProfilePictureWidget(
              imageUrl: profile.profilePictureUrl,
              size: 120,
              onTap: widget.isOwnProfile
                  ? () {
                      // Will implement picture upload in Phase 6
                    }
                  : null,
            ),
            const SizedBox(height: 24),

            // Username display (read-only)
            Text(
              profile.username,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // T043: Privacy Badge (if private)
            if (profile.isPrivateProfile)
              Chip(
                avatar: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Private Profile'),
                backgroundColor: Colors.blue[100],
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            const SizedBox(height: 16),

            // T041: Bio section with empty placeholder
            Card(
              elevation: 0,
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bio',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.aboutMe.isNotEmpty
                          ? profile.aboutMe
                          : 'No bio added yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: profile.aboutMe.isEmpty
                            ? FontStyle.italic
                            : null,
                        color: profile.aboutMe.isEmpty
                            ? Colors.grey[600]
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Edit Profile button (for own profile)
            if (widget.isOwnProfile)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileEditScreen(profile: profile),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                ),
              ),

            // Active device sessions section (own profile only — GAP-005/T031)
            if (widget.isOwnProfile && token != null) ...[
              const SizedBox(height: 32),
              _ActiveSessionsSection(token: token),
            ],

            // Invite button (for other profiles)
            if (!widget.isOwnProfile)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingInvite ? null : _sendInvite,
                  icon: _isLoadingInvite
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.person_add),
                  label: _isLoadingInvite
                      ? const Text('Sending...')
                      : const Text('Send Invitation'),
                ),
              ),

            if (_inviteError != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    border: Border.all(color: Colors.red[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _inviteError!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _refreshProfile(WidgetRef ref, String? token) {
    if (token == null) {
      // ignore: unused_result
      ref.refresh(userProfileProvider(widget.userId));
      return;
    }

    // ignore: unused_result
    ref.refresh(userProfileWithTokenProvider((widget.userId, token)));
  }
}

// ---------------------------------------------------------------------------
// Active Sessions Section  (GAP-005 / T031)
// ---------------------------------------------------------------------------

class _DeviceSessionInfo {
  final String id;
  final String deviceId;
  final String? deviceName;
  final DateTime lastActiveAt;

  _DeviceSessionInfo({
    required this.id,
    required this.deviceId,
    this.deviceName,
    required this.lastActiveAt,
  });

  factory _DeviceSessionInfo.fromJson(Map<String, dynamic> json) {
    final lastSeenRaw =
        json['lastSeenAt'] ?? json['lastActiveAt'] ?? json['createdAt'];
    return _DeviceSessionInfo(
      id: (json['id'] ?? json['deviceId'] ?? '') as String,
      deviceId: json['deviceId'] as String,
      deviceName: (json['deviceName'] ?? json['userAgent']) as String?,
      lastActiveAt: DateTime.parse(lastSeenRaw as String),
    );
  }
}

/// Shows the list of active device sessions for the current user and allows
/// selective logout from individual sessions or all other sessions.
class _ActiveSessionsSection extends StatefulWidget {
  final String token;

  const _ActiveSessionsSection({required this.token});

  @override
  State<_ActiveSessionsSection> createState() => _ActiveSessionsSectionState();
}

class _ActiveSessionsSectionState extends State<_ActiveSessionsSection> {
  static const String _baseUrl = 'http://localhost:8081';

  List<_DeviceSessionInfo> _sessions = [];
  bool _isLoading = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/auth/sessions'),
            headers: {'Authorization': 'Bearer ${widget.token}'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (mounted) {
          setState(() {
            _sessions = list
                .map(
                  (e) => _DeviceSessionInfo.fromJson(e as Map<String, dynamic>),
                )
                .toList();
            _loaded = true;
          });
        }
      } else {
        if (mounted) {
          setState(
            () => _error = 'Failed to load sessions (${response.statusCode})',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Network error loading sessions');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _revoke(String deviceId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/api/auth/sessions/$deviceId'),
            headers: {'Authorization': 'Bearer ${widget.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          AppFeedbackService.showInfo('Session revoked.');
          _load();
        }
      } else {
        if (mounted) {
          AppFeedbackService.showError('Failed to revoke session.');
        }
      }
    } catch (e) {
      AppExceptionLogger.log(e, context: '_ActiveSessionsSection._revoke');
      if (mounted) AppFeedbackService.showError('Network error.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Active Sessions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh sessions',
                onPressed: _load,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13))
        else if (!_loaded && !_isLoading)
          const SizedBox.shrink()
        else if (_sessions.isEmpty)
          Text(
            'No active sessions found.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          )
        else
          ...(_sessions.map(
            (session) => _SessionTile(
              session: session,
              onRevoke: () => _revoke(session.deviceId),
            ),
          )),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final _DeviceSessionInfo session;
  final VoidCallback onRevoke;

  const _SessionTile({required this.session, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.devices, color: Colors.indigo),
        title: Text(
          session.deviceName ?? 'Unknown device',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Last seen: ${_formatRelative(session.lastActiveAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.logout, color: Colors.red),
          tooltip: 'Sign out this session',
          onPressed: () =>
              showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out session?'),
                  content: const Text(
                    'This will revoke access for the selected device.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Sign out',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ).then((confirmed) {
                if (confirmed == true) onRevoke();
              }),
        ),
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
