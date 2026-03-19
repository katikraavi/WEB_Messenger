import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/search/providers/search_results_provider.dart';
import '../../../features/search/services/search_service.dart';
import '../providers/invites_provider.dart';
import '../services/invite_error_handler.dart';
import '../../../features/chats/widgets/user_avatar_widget.dart';

/// Screen for selecting a user to send an invitation to
class SendInvitePickerScreen extends ConsumerStatefulWidget {
  const SendInvitePickerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SendInvitePickerScreen> createState() =>
      _SendInvitePickerScreenState();
}

class _SendInvitePickerScreenState extends ConsumerState<SendInvitePickerScreen> {
  final _searchController = TextEditingController();
  List<UserSearchResult> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_performSearch);
  }

  void _performSearch() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      // Get search service with token
      final searchService = await ref.read(searchServiceWithTokenProvider.future);
      final results = await searchService.searchByUsername(query);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _isSearching = false;
          _searchResults = [];
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendInviteToUser(UserSearchResult user) async {
    try {
      await ref.read(sendInviteMutationProvider.notifier).sendInvite(user.userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to ${user.username}!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
        // Don't close, allow further invites
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = InviteErrorHandler.getUserFriendlyMessage(e);
        InviteErrorHandler.logError('Send Invite', e);
        
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Send Invitation Failed'),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sendMutation = ref.watch(sendInviteMutationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Invitation'),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by username...',
                prefixIcon: _isSearching
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _searchError = null;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          // Error message
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _searchError!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ),
          // User list
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_outline,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(_searchController.text.isEmpty
                                ? 'Search for users to invite'
                                : 'No users found matching "${_searchController.text}"'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final isSending = sendMutation.isLoading;

                          return ListTile(
                            leading: UserAvatarWidget(
                              imageUrl: user.profilePictureUrl,
                              radius: 20,
                              username: user.username,
                            ),
                            title: Text(user.username),
                            subtitle: Text(user.email),
                            trailing: ElevatedButton.icon(
                              onPressed: isSending ? null : () => _sendInviteToUser(user),
                              icon: Icon(isSending ? Icons.hourglass_empty : Icons.send),
                              label: const Text('Invite'),
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
