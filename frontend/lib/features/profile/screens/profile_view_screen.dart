import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/profile_picture_widget.dart';
import 'profile_edit_screen.dart';

class ProfileViewScreen extends ConsumerWidget {
  final String userId;
  final bool isOwnProfile;

  const ProfileViewScreen({
    required this.userId,
    this.isOwnProfile = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the profile provider for the given userId
    final profileAsync = ref.watch(userProfileProvider(userId));

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: _buildLoadingSkeleton(context),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: _buildErrorState(context, ref, error.toString()),
      ),
      data: (profile) => Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            if (isOwnProfile)
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
        body: _buildProfileContent(
          context,
          ref,
          profile,
        ),
      ),
    );
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
              child: const Center(
                child: CircularProgressIndicator(),
              ),
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
  Widget _buildErrorState(BuildContext context, WidgetRef ref, String errorMsg) {
    return RefreshIndicator(
      onRefresh: () async {
        // ignore: unused_result
        ref.refresh(userProfileProvider(userId));
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
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
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
                    // ignore: unused_result
                    ref.refresh(userProfileProvider(userId));
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
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh profile via Riverpod
        // ignore: unused_result
        ref.refresh(userProfileProvider(userId));
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
              onTap: isOwnProfile
                  ? () {
                      // Will implement picture upload in Phase 6
                    }
                  : null,
            ),
            const SizedBox(height: 24),

            // Username display (read-only)
            Text(
              profile.username,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
            if (isOwnProfile)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileEditScreen(profile: profile!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
