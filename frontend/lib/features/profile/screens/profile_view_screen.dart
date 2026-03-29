import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart' as provider;
import 'package:frontend/core/notifications/app_feedback_service.dart';
import 'package:frontend/core/services/app_exception_logger.dart';
import 'package:frontend/core/services/api_client.dart';
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
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _inviteService = InviteApiService(baseUrl: ApiClient.getBaseUrl());
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
            final isWeb = MediaQuery.of(context).size.width > 900;
            
            // On web, show side-by-side layout if in edit mode
            if (isWeb && _isEditMode) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Profile & Edit'),
                ),
                body: Row(
                  children: [
                    // Profile view on left (60% width)
                    Expanded(
                      flex: 60,
                      child: _buildProfileContent(context, ref, profile, token),
                    ),
                    // Divider
                    Container(
                      width: 1,
                      color: Colors.grey[300],
                    ),
                    // Edit form on right (40% width)
                    Expanded(
                      flex: 40,
                      child: Container(
                        color: Colors.grey[50],
                        child: Stack(
                          children: [
                            // Close button in top-right
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _isEditMode = false;
                                  });
                                },
                              ),
                            ),
                            // Edit form
                            ProfileEditScreenContent(
                              profile: profile,
                              onSaveSuccess: () {
                                setState(() {
                                  _isEditMode = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            
            // Default view (mobile or non-edit mode)
            return Scaffold(
              appBar: AppBar(
                title: const Text('Profile'),
                actions: [
                  if (widget.isOwnProfile)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        if (isWeb) {
                          // On web, show edit panel on the right
                          setState(() {
                            _isEditMode = true;
                          });
                        } else {
                          // On mobile, navigate to edit screen
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProfileEditScreen(profile: profile),
                            ),
                          );
                        }
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
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
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

            // Active device sessions section (own profile only — GAP-005/T031)
            if (widget.isOwnProfile && token != null) ...[
              const SizedBox(height: 32),
              _ActiveSessionsSection(token: token),
              const SizedBox(height: 32),
              const ManualUserDeleteSection(),
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
          ),
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
  static String get _baseUrl => ApiClient.getBaseUrl();

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

class _DeletePreviewResult {
  final Map<String, dynamic> user;
  final Map<String, dynamic> relatedCounts;

  const _DeletePreviewResult({
    required this.user,
    required this.relatedCounts,
  });

  factory _DeletePreviewResult.fromJson(Map<String, dynamic> json) {
    return _DeletePreviewResult(
      user: (json['user'] as Map<String, dynamic>? ?? const {}),
      relatedCounts:
          (json['related_counts'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class ManualUserDeleteSection extends StatefulWidget {
  const ManualUserDeleteSection({super.key});

  @override
  State<ManualUserDeleteSection> createState() =>
      _ManualUserDeleteSectionState();
}

class _ManualUserDeleteSectionState extends State<ManualUserDeleteSection> {
  static String get _baseUrl => ApiClient.getBaseUrl();

  final TextEditingController _adminKeyController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _confirmEmailController = TextEditingController();
  final TextEditingController _confirmPhraseController = TextEditingController();

  bool _isPreviewing = false;
  bool _isDeleting = false;
  String? _error;
  _DeletePreviewResult? _preview;

  @override
  void dispose() {
    _adminKeyController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _confirmPhraseController.dispose();
    super.dispose();
  }

  Future<void> _previewDelete() async {
    final email = _emailController.text.trim().toLowerCase();
    final adminKey = _adminKeyController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email first.');
      return;
    }
    if (adminKey.isEmpty) {
      setState(() => _error = 'Admin delete key is required.');
      return;
    }

    setState(() {
      _isPreviewing = true;
      _error = null;
      _preview = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/admin/users/delete-preview'),
            headers: {
              'Content-Type': 'application/json',
              'x-admin-delete-key': adminKey,
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 20));

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _preview = _DeletePreviewResult.fromJson(body);
          _error = null;
        });
      } else {
        final message = body['error']?.toString() ??
            'Preview failed (${response.statusCode})';
        if (!mounted) return;
        setState(() => _error = message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Network error while previewing delete.');
    } finally {
      if (mounted) {
        setState(() => _isPreviewing = false);
      }
    }
  }

  Future<void> _deleteUser() async {
    final email = _emailController.text.trim().toLowerCase();
    final confirmEmail = _confirmEmailController.text.trim().toLowerCase();
    final confirmPhrase = _confirmPhraseController.text.trim();
    final adminKey = _adminKeyController.text.trim();

    if (_preview == null) {
      setState(() => _error = 'Run preview first before deleting.');
      return;
    }
    if (adminKey.isEmpty) {
      setState(() => _error = 'Admin delete key is required.');
      return;
    }
    if (confirmEmail != email) {
      setState(() => _error = 'Confirmation email must exactly match target email.');
      return;
    }
    if (confirmPhrase != 'DELETE USER') {
      setState(() => _error = 'Type DELETE USER exactly to confirm.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user from database?'),
        content: Text(
          'This permanently deletes $email and related records. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/admin/users/delete'),
            headers: {
              'Content-Type': 'application/json',
              'x-admin-delete-key': adminKey,
            },
            body: jsonEncode({
              'email': email,
              'confirm_email': confirmEmail,
              'confirm_phrase': confirmPhrase,
            }),
          )
          .timeout(const Duration(seconds: 25));

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 200) {
        if (!mounted) return;
        AppFeedbackService.showInfo('User deleted successfully.');
        setState(() {
          _preview = null;
          _confirmEmailController.clear();
          _confirmPhraseController.clear();
        });
      } else {
        final message = body['error']?.toString() ??
            'Delete failed (${response.statusCode})';
        if (!mounted) return;
        setState(() => _error = message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Network error while deleting user.');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dangerColor = Colors.red.shade700;

    return Card(
      color: const Color(0xFFFFF7F7),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: dangerColor),
                const SizedBox(width: 8),
                Text(
                  'Manual User Delete (Admin)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: dangerColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use only for manual tester resets. Requires ADMIN_DELETE_KEY on backend.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.red.shade700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _adminKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin delete key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Target email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: (_isPreviewing || _isDeleting) ? null : _previewDelete,
                icon: _isPreviewing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.preview_outlined),
                label: const Text('Preview'),
              ),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User: ${_preview!.user['username']} (${_preview!.user['email']})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Related rows: ${_preview!.relatedCounts.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmEmailController,
                decoration: const InputDecoration(
                  labelText: 'Type target email again',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmPhraseController,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE USER to confirm',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dangerColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_isDeleting || _isPreviewing) ? null : _deleteUser,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.delete_forever),
                  label: const Text('Delete user permanently'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
