import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:frontend/core/services/api_client.dart';

import '../../auth/providers/auth_provider.dart';
import '../../invitations/services/group_invite_service.dart';
import '../../search/services/search_service.dart';
import '../providers/active_chats_provider.dart';
import '../providers/chats_provider.dart';
import '../widgets/user_avatar_widget.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String initialGroupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.initialGroupName,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  static String get _baseUrl => ApiClient.getBaseUrl();

  late final GroupInviteService _service;
  bool _isLoading = true;
  String? _errorMessage;
  GroupSummaryModel? _group;
  List<GroupMemberModel> _members = const [];
  List<GroupSentInviteModel> _sentInvites = const [];

  @override
  void initState() {
    super.initState();
    _service = GroupInviteService(baseUrl: _baseUrl);
    _load();
  }

  String? get _token {
    final authProvider = provider_pkg.Provider.of<AuthProvider>(
      context,
      listen: false,
    );
    return authProvider.token;
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Not authenticated';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.fetchGroupDetails(token: token, groupId: widget.groupId),
        _service.fetchGroupMembers(token: token, groupId: widget.groupId),
        _service.fetchGroupSentInvites(token: token, groupId: widget.groupId),
      ]);

      if (!mounted) return;

      setState(() {
        _group = results[0] as GroupSummaryModel;
        _members = results[1] as List<GroupMemberModel>;
        _sentInvites = results[2] as List<GroupSentInviteModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openInvitePeople() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _GroupInvitePeopleScreen(
          token: token,
          groupId: widget.groupId,
          existingMemberIds: _members.map((member) => member.userId).toSet(),
          pendingInviteUserIds:
              _sentInvites.map((invite) => invite.receiverId).toSet(),
        ),
      ),
    );

    if (sent == true) {
      await _load();
    }
  }

  Future<void> _deleteInvite(GroupSentInviteModel invite) async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _service.deleteInvite(token: token, inviteId: invite.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted invitation for ${invite.receiverUsername}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete invitation: $e')),
      );
    }
  }

  Future<void> _leaveGroup() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text('You will be removed from this group chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.leaveGroup(token: token, groupId: widget.groupId);
      ref.invalidate(chatsProvider(token));
      ref.invalidate(activeChatListProvider(token));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left group successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave group: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _group?.name ?? widget.initialGroupName;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Invite People',
            onPressed: _isLoading ? null : _openInvitePeople,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Leave Group',
            onPressed: _isLoading ? null : _leaveGroup,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(_errorMessage!, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade100,
                            child: const Icon(Icons.group, color: Colors.indigo),
                          ),
                          title: Text(title),
                          subtitle: Text(
                            '${_group?.memberCount ?? _members.length} member${(_group?.memberCount ?? _members.length) == 1 ? '' : 's'} • ${_group?.myRole ?? 'member'}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Members',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._members.map(
                        (member) => Card(
                          child: ListTile(
                            leading: UserAvatarWidget(
                              imageUrl: member.profilePictureUrl,
                              radius: 20,
                              username: member.username,
                            ),
                            title: Text(member.username),
                            subtitle: Text(member.role),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pending Invitations',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            onPressed: _openInvitePeople,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Invite'),
                          ),
                        ],
                      ),
                      if (_sentInvites.isEmpty)
                        const Card(
                          child: ListTile(
                            title: Text('No pending invitations'),
                          ),
                        )
                      else
                        ..._sentInvites.map(
                          (invite) => Card(
                            child: ListTile(
                              leading: UserAvatarWidget(
                                imageUrl: invite.receiverProfilePictureUrl,
                                radius: 20,
                                username: invite.receiverUsername,
                              ),
                              title: Text(invite.receiverUsername),
                              subtitle: Text(invite.receiverEmail),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Delete Invitation',
                                onPressed: () => _deleteInvite(invite),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _GroupInvitePeopleScreen extends StatefulWidget {
  final String token;
  final String groupId;
  final Set<String> existingMemberIds;
  final Set<String> pendingInviteUserIds;

  const _GroupInvitePeopleScreen({
    required this.token,
    required this.groupId,
    required this.existingMemberIds,
    required this.pendingInviteUserIds,
  });

  @override
  State<_GroupInvitePeopleScreen> createState() => _GroupInvitePeopleScreenState();
}

class _GroupInvitePeopleScreenState extends State<_GroupInvitePeopleScreen> {
  static String get _baseUrl => ApiClient.getBaseUrl();

  final TextEditingController _searchController = TextEditingController();
  late final SearchService _searchService;
  late final GroupInviteService _groupInviteService;
  bool _isSearching = false;
  bool _isInviting = false;
  String? _errorMessage;
  List<UserSearchResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _searchService = SearchService(
      baseUrl: _baseUrl,
      getAuthToken: () => widget.token,
    );
    _groupInviteService = GroupInviteService(baseUrl: _baseUrl);
    _searchController.addListener(_performSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await _searchService.searchByUsername(query);
      if (!mounted) return;
      setState(() {
        _results = results
            .where(
              (user) => !widget.existingMemberIds.contains(user.userId) &&
                  !widget.pendingInviteUserIds.contains(user.userId),
            )
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _results = const [];
        _isSearching = false;
      });
    }
  }

  Future<void> _invite(UserSearchResult user) async {
    setState(() {
      _isInviting = true;
      _errorMessage = null;
    });

    try {
      await _groupInviteService.sendGroupInvite(
        token: widget.token,
        groupId: widget.groupId,
        targetUserId: user.userId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent to ${user.username}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInviting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite People')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search users by username',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Search for users to invite'
                              : 'No matching users available to invite',
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return ListTile(
                            leading: UserAvatarWidget(
                              imageUrl: user.profilePictureUrl,
                              radius: 20,
                              username: user.username,
                            ),
                            title: Text(user.username),
                            subtitle: Text(user.email),
                            trailing: ElevatedButton(
                              onPressed: _isInviting ? null : () => _invite(user),
                              child: const Text('Invite'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}