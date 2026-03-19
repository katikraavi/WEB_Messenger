import 'package:flutter/material.dart';
import 'invite_service.dart';
import '../../features/chats/widgets/user_avatar_widget.dart';

class SelectRecipientsScreen extends StatefulWidget {
  const SelectRecipientsScreen({Key? key}) : super(key: key);

  @override
  State<SelectRecipientsScreen> createState() => _SelectRecipientsScreenState();
}

class _SelectRecipientsScreenState extends State<SelectRecipientsScreen> {
  late InviteService _inviteService;
  late TextEditingController _searchController;
  List<User> _searchResults = [];
  Set<String> _selectedUserIds = {};
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _inviteService = InviteService();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inviteService.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _inviteService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to search users: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _sendInvites() async {
    if (_selectedUserIds.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one user';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await _inviteService.sendBulkInvites(_selectedUserIds.toList());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully sent ${_selectedUserIds.length} invite(s)')),
        );
        
        // Clear selections
        setState(() {
          _selectedUserIds.clear();
          _searchController.clear();
          _searchResults = [];
          _isSending = false;
        });

        // Optionally navigate back
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send invites: $e';
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Recipients'),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    '${_selectedUserIds.length} selected',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search users to invite',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade100,
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
            const Expanded(
              child: Center(
                child: Text('No users found'),
              ),
            )
          else if (_searchResults.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Search for users to invite'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  final isSelected = _selectedUserIds.contains(user.id);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => _toggleUserSelection(user.id),
                    leading: UserAvatarWidget(
                      imageUrl: user.profilePictureUrl,
                      radius: 20,
                      username: user.username,
                    ),
                    title: Text(user.username),
                    subtitle: Text(user.email),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedUserIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSending ? null : _sendInvites,
              label: Text(_isSending ? 'Sending...' : 'Send Invites'),
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send),
            )
          : null,
    );
  }
}
