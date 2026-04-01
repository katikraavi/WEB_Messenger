import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../models/user_profile.dart';
import '../models/profile_form_state.dart';
import '../providers/profile_form_state_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/profile_api_service.dart';
import '../widgets/profile_image_upload_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chats/providers/user_profile_provider.dart' as chats_profile_provider;

/// Screen for editing user profile information
/// 
/// Allows users to edit username and bio with live validation
/// and character counters. Uses form state provider for state management.
/// 
/// T056: Implements TextEditingController initialization for username + bio
/// T057-T062: Implements all UI elements and state watching
class ProfileEditScreen extends ConsumerStatefulWidget {
  final UserProfile profile;
  final VoidCallback? onSaveSuccess;

  const ProfileEditScreen({
    required this.profile,
    this.onSaveSuccess,
    super.key,
  });

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  // T056: TextEditingControllers initialized in initState
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    // T056: Pre-populate with original profile values
    _usernameController = TextEditingController(text: widget.profile.username);
    _bioController = TextEditingController(text: widget.profile.aboutMe);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // T062: Watch form state provider to rebuild on state changes
    final formState = ref.watch(profileFormStateProvider(widget.profile));

    return PopScope(
      canPop: !formState.isDirty,
      onPopInvoked: (didPop) {
        if (!didPop && formState.isDirty) {
          _showCancelConfirmation(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (formState.isDirty) {
                _showCancelConfirmation(context);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          // T138: Save and Cancel buttons in AppBar for easy access
          actions: [
            if (formState.error != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Tooltip(
                    message: formState.error?.message ?? 'Fix errors to save',
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red[300],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Tooltip(
                  message: 'Cancel editing and lose changes',
                  child: TextButton(
                    onPressed: () {
                      if (formState.isDirty) {
                        _showCancelConfirmation(context);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Cancel'),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                message: 'Save profile changes',
                child: ElevatedButton.icon(
                  onPressed: (formState.isDirty &&
                          !formState.isLoading &&
                          formState.error == null)
                      ? () => _saveProfile(context, ref, formState)
                      : null,
                  icon: formState.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // T146: Show error message prominently at the top
              if (formState.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    border: Border.all(color: Colors.red[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fix this error to save:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formState.error?.message ?? 'Unknown error',
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // T079: Image upload widget
              Center(
                child: ProfileImageUploadWidget(
                  currentImageUrl: widget.profile.profilePictureUrl,
                  userId: widget.profile.userId,
                ),
              ),
              const SizedBox(height: 24),

              // T057: Username text field with character counter
              _buildUsernameField(ref, formState),
              const SizedBox(height: 24),

              // T058: Bio text area with character counter
              _buildBioField(ref, formState),
              const SizedBox(height: 24),

              // T059: Privacy toggle
              _buildPrivacyToggle(ref, formState),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// T057: Build username text field with character counter
  Widget _buildUsernameField(WidgetRef ref, ProfileFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Username',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            // T057: Live character counter (3-32 limit)
            Text(
              '${_usernameController.text.length}/32',
              style: TextStyle(
                fontSize: 12,
                color: _usernameController.text.length > 32
                    ? Colors.red
                    : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            hintText: 'Enter your username',
            helperText: 'Letters, numbers, underscores only (3-32 characters)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            errorText:
                formState.error == ValidationError.invalidUsername
                    ? formState.error?.message
                    : null,
          ),
          onChanged: (value) {
            // T057: Update form state on change with real-time validation
            // Get the sanitized username (invalid characters removed)
            final notifier = ref.read(profileFormStateProvider(widget.profile).notifier);
            final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
            
            // If sanitization removed characters (e.g., spaces), update controller & show feedback
            if (sanitized != value && value.isNotEmpty) {
              _usernameController.text = sanitized;
              _usernameController.selection = TextSelection.fromPosition(
                TextPosition(offset: sanitized.length),
              );
              
              // Show brief feedback that invalid character was removed
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Invalid characters removed (only letters, numbers, _, - allowed)'),
                  duration: const Duration(milliseconds: 1500),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
            
            notifier.updateUsername(sanitized);
            setState(() {}); // Trigger counter update
          },
          maxLength: 32,
          buildCounter: (context,
              {required currentLength, required isFocused, maxLength}) {
            return const SizedBox.shrink();
          },
        ),
        if (formState.error == ValidationError.invalidUsername)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              formState.error?.message ?? 'Invalid username',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// T058: Build bio text area with character counter
  Widget _buildBioField(WidgetRef ref, ProfileFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'About Me',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            // T058: Live character counter (0-500 limit)
            Text(
              '${_bioController.text.length}/500',
              style: TextStyle(
                fontSize: 12,
                color:
                    _bioController.text.length > 500 ? Colors.red : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bioController,
          decoration: InputDecoration(
            hintText: 'Tell us about yourself',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            errorText: formState.error == ValidationError.invalidBio
                ? formState.error?.message
                : null,
          ),
          onChanged: (value) {
            // T058: Update form state on change
            ref
                .read(profileFormStateProvider(widget.profile).notifier)
                .updateBio(value);
            setState(() {}); // Trigger counter update
          },
          maxLines: 4,
          maxLength: 500,
          buildCounter: (context,
              {required currentLength, required isFocused, maxLength}) {
            return const SizedBox.shrink();
          },
        ),
        if (formState.error == ValidationError.invalidBio)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              formState.error?.message ?? 'Invalid bio',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// T059: Build privacy toggle for private profile setting
  Widget _buildPrivacyToggle(WidgetRef ref, ProfileFormState formState) {
    return Card(
      child: SwitchListTile(
        title: const Text(
          'Private Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Only contacts can see your profile'),
        value: formState.isPrivateProfile,
        onChanged: (value) {
          ref
              .read(profileFormStateProvider(widget.profile).notifier)
              .updatePrivacy(value);
        },
      ),
    );
  }

  /// T061: Save profile with success toast notification
  Future<void> _saveProfile(
    BuildContext context,
    WidgetRef ref,
    ProfileFormState formState,
  ) async {
    final formNotifier = ref.read(profileFormStateProvider(widget.profile).notifier);

    // Validate form before saving
    if (!formNotifier.validate()) {
      // Error displayed in form state
      return;
    }

    try {
      formNotifier.setLoading(true);

      // Get auth token from auth provider
      final authProvider = provider_pkg.Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        formNotifier.setLoading(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not authenticated - please login again'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // T063: Call API to update profile
      final apiService = ProfileApiService();
      final updatedProfile = await apiService.updateProfile(
        username: formState.username,
        bio: formState.bio,
        isPrivateProfile: formState.isPrivateProfile,
        token: token,
      );

      formNotifier.setLoading(false);

      // T061: Show success toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh profile data to show updated information
        // This will fetch fresh data from the backend, including any newly uploaded image
        try {
          final refreshedProfile = await ref.refresh(
            userProfileWithTokenProvider((widget.profile.userId, token)).future,
          );
        } catch (e) {
        }

        // Also invalidate the chats module's profile provider so chat list avatars update
        if (token != null && token.isNotEmpty) {
          ref.invalidate(
            chats_profile_provider.userProfileProvider((widget.profile.userId, token)),
          );
        }
        
        // Wait a brief moment to ensure UI updates with new data
        await Future.delayed(const Duration(milliseconds: 300));

        // Pop screen after successful save and profile is refreshed
        if (mounted) {
          Navigator.pop(context);
          widget.onSaveSuccess?.call();
        }
      }
    } catch (e) {
      formNotifier.setLoading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// T060: Show confirmation dialog before canceling with unsaved changes
  void _showCancelConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Discard changes?'),
          content:
              const Text('You have unsaved changes. Do you want to discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () {
                // Revert changes via form notifier
                ref
                    .read(profileFormStateProvider(widget.profile).notifier)
                    .reset();
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close edit screen
              },
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
  }
}

/// Separate content widget for use in side panel on web
/// Replicates ProfileEditScreen without Scaffold wrapper
class ProfileEditScreenContent extends ConsumerStatefulWidget {
  final UserProfile profile;
  final VoidCallback? onSaveSuccess;

  const ProfileEditScreenContent({
    required this.profile,
    this.onSaveSuccess,
    super.key,
  });

  @override
  ConsumerState<ProfileEditScreenContent> createState() =>
      _ProfileEditScreenContentState();
}

class _ProfileEditScreenContentState extends ConsumerState<ProfileEditScreenContent> {
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.profile.username);
    _bioController = TextEditingController(text: widget.profile.aboutMe);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(profileFormStateProvider(widget.profile));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title for side panel
          Text(
            'Edit Profile',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Error message
          if (formState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[100],
                border: Border.all(color: Colors.red[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fix this error to save:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formState.error?.message ?? 'Unknown error',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Image upload widget
          Center(
            child: ProfileImageUploadWidget(
              currentImageUrl: widget.profile.profilePictureUrl,
              userId: widget.profile.userId,
            ),
          ),
          const SizedBox(height: 24),

          // Username field
          _buildUsernameField(ref, formState),
          const SizedBox(height: 24),

          // Bio field
          _buildBioField(ref, formState),
          const SizedBox(height: 24),

          // Privacy toggle
          _buildPrivacyToggle(ref, formState),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (formState.isDirty &&
                      !formState.isLoading &&
                      formState.error == null)
                  ? () => _saveProfile(context, ref, formState)
                  : null,
              icon: formState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save Changes'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildUsernameField(WidgetRef ref, ProfileFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Username',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              '${_usernameController.text.length}/32',
              style: TextStyle(
                fontSize: 12,
                color: _usernameController.text.length > 32
                    ? Colors.red
                    : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            hintText: 'Enter your username',
            helperText: 'Letters, numbers, underscores only (3-32 characters)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            errorText: formState.error == ValidationError.invalidUsername
                ? formState.error?.message
                : null,
          ),
          onChanged: (value) {
            final notifier =
                ref.read(profileFormStateProvider(widget.profile).notifier);
            final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

            if (sanitized != value && value.isNotEmpty) {
              _usernameController.text = sanitized;
              _usernameController.selection = TextSelection.fromPosition(
                TextPosition(offset: sanitized.length),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                      'Invalid characters removed (only letters, numbers, _, - allowed)'),
                  duration: const Duration(milliseconds: 1500),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ),
              );
            }

            notifier.updateUsername(sanitized);
            setState(() {});
          },
          maxLength: 32,
          buildCounter: (context,
              {required currentLength, required isFocused, maxLength}) {
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildBioField(WidgetRef ref, ProfileFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'About Me',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              '${_bioController.text.length}/500',
              style: TextStyle(
                fontSize: 12,
                color: _bioController.text.length > 500 ? Colors.red : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bioController,
          decoration: InputDecoration(
            hintText: 'Tell us about yourself',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            errorText: formState.error == ValidationError.invalidBio
                ? formState.error?.message
                : null,
          ),
          onChanged: (value) {
            ref
                .read(profileFormStateProvider(widget.profile).notifier)
                .updateBio(value);
            setState(() {});
          },
          maxLines: 4,
          maxLength: 500,
          buildCounter: (context,
              {required currentLength, required isFocused, maxLength}) {
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildPrivacyToggle(WidgetRef ref, ProfileFormState formState) {
    return Card(
      child: SwitchListTile(
        title: const Text(
          'Private Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Only contacts can see your profile'),
        value: formState.isPrivateProfile,
        onChanged: (value) {
          ref
              .read(profileFormStateProvider(widget.profile).notifier)
              .updatePrivacy(value);
        },
      ),
    );
  }

  Future<void> _saveProfile(
    BuildContext context,
    WidgetRef ref,
    ProfileFormState formState,
  ) async {
    final formNotifier =
        ref.read(profileFormStateProvider(widget.profile).notifier);

    if (!formNotifier.validate()) {
      return;
    }

    try {
      formNotifier.setLoading(true);

      final authProvider =
          provider_pkg.Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final apiService = ProfileApiService();
      await apiService.updateProfile(
        token: token,
        username: _usernameController.text,
        bio: _bioController.text,
        isPrivateProfile: formState.isPrivateProfile,
      );

      if (!mounted) return;

      // Reset form to clean state after successful save
      formNotifier.reset();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );

      widget.onSaveSuccess?.call();
    } catch (e) {
      formNotifier.setLoading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
