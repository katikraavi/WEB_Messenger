import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:frontend/core/services/api_client.dart';

import '../../auth/providers/auth_provider.dart';
import '../../invitations/services/group_invite_service.dart';
import 'chat_detail_screen.dart';

class SearchGroupsScreen extends StatefulWidget {
  const SearchGroupsScreen({super.key});

  @override
  State<SearchGroupsScreen> createState() => _SearchGroupsScreenState();
}

class _SearchGroupsScreenState extends State<SearchGroupsScreen> {
  static String get _baseUrl => ApiClient.getBaseUrl();

  final TextEditingController _searchController = TextEditingController();
  late final GroupInviteService _service;
  bool _isLoading = true;
  String? _errorMessage;
  List<GroupSummaryModel> _groups = const [];

  @override
  void initState() {
    super.initState();
    _service = GroupInviteService(baseUrl: _baseUrl);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final authProvider = provider_pkg.Provider.of<AuthProvider>(
      context,
      listen: false,
    );
    final token = authProvider.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'Not authenticated';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _service.fetchGroups(token: token);
      if (!mounted) return;
      setState(() {
        _groups = groups;
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

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredGroups = _groups
        .where((group) => group.name.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Search Groups')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search your groups',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
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
                    : filteredGroups.isEmpty
                        ? const Center(child: Text('No groups found'))
                        : ListView.builder(
                            itemCount: filteredGroups.length,
                            itemBuilder: (context, index) {
                              final group = filteredGroups[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.indigo.shade100,
                                  child: const Icon(Icons.group, color: Colors.indigo),
                                ),
                                title: Text(group.name),
                                subtitle: Text(
                                  '${group.memberCount} member${group.memberCount == 1 ? '' : 's'} • ${group.myRole}',
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChatDetailScreen(
                                        chatId: group.id,
                                        otherUserId: group.id,
                                        otherUserName: group.name,
                                        isGroup: true,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}