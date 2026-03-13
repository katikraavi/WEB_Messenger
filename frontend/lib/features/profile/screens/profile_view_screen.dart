import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_profile_provider.dart';

class ProfileViewScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const ProfileViewScreen({
    required this.userId,
    this.isOwnProfile = false,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends ConsumerState<ProfileViewScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch profile on init
    Future.microtask(() {
      ref.read(userProfileProvider.notifier).fetchProfile(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileProvider);

    if (profileState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profileState.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${profileState.error}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(userProfileProvider.notifier).fetchProfile(widget.userId);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = profileState.profile;
    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('No profile data')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (widget.isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SizedBox(), // TODO: Navigate to edit screen
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 60,
              backgroundImage: profile.profilePictureUrl != null
                  ? NetworkImage(profile.profilePictureUrl!)
                  : null,
              child: profile.profilePictureUrl == null
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
            const SizedBox(height: 16),

            // Username
            Text(
              profile.username,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Privacy indicator
            if (profile.isPrivateProfile)
              Chip(
                avatar: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Private Profile'),
              ),
            const SizedBox(height: 16),

            // About me
            if (profile.aboutMe.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    profile.aboutMe,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            if (profile.aboutMe.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No bio added yet',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Button group for own profile
            if (widget.isOwnProfile)
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Navigate to edit screen
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
              ),
          ],
        ),
      ),
    );
  }
}
