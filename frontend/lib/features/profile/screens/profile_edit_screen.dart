import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../models/profile_form_state.dart';
import '../providers/profile_form_state_provider.dart';
import '../services/profile_api_service.dart';
import '../widgets/profile_image_upload_widget.dart';

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
          actions: [
            // T059: Save button enabled only when isDirty=true
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // T079: Image upload widget
              Center(
                child: ProfileImageUploadWidget(
                  currentImageUrl: widget.profile.profilePictureUrl,
                ),
              ),
              const SizedBox(height: 24),

              // T057: Username text field with character counter
              _buildUsernameField(ref, formState),
              const SizedBox(height: 24),

              // T058: Bio text area with character counter
              _buildBioField(ref, formState),
              const SizedBox(height: 24),

              // T060: Cancel button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
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
            // T057: Update form state on change
            ref
                .read(profileFormStateProvider(widget.profile).notifier)
                .updateUsername(value);
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

      // T063: Call API to update profile
      final apiService = ProfileApiService();
      final updatedProfile = await apiService.updateProfile(
        username: formState.username,
        bio: formState.bio,
        isPrivateProfile: formState.isPrivateProfile,
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

        // Pop screen after successful save
        Navigator.pop(context);
        widget.onSaveSuccess?.call();
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
