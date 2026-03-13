import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user.dart';
import '../providers/profile_edit_provider.dart';
import '../providers/profile_image_provider.dart';
import '../services/image_picker_service.dart';
import '../widgets/profile_image_upload_widget.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final User profile;
  final VoidCallback? onSaveSuccess;

  const ProfileEditScreen({
    required this.profile,
    this.onSaveSuccess,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final String editProviderId;

  @override
  void initState() {
    super.initState();
    // Use profile data as provider key
    editProviderId = '${widget.profile.userId}-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(profileEditFormProvider((
      widget.profile.username,
      widget.profile.aboutMe,
      widget.profile.isPrivateProfile,
    )));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (editState.isDirty)
            TextButton(
              onPressed: editState.isLoading
                  ? null
                  : () {
                ref.read(profileEditFormProvider((
                  widget.profile.username,
                  widget.profile.aboutMe,
                  widget.profile.isPrivateProfile,
                )).notifier).saveProfile();
                widget.onSaveSuccess?.call();
                Navigator.pop(context);
              },
              child: editState.isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture Section
            const ProfileImageUploadWidget(),
            const SizedBox(height: 24),

            // Username field
            TextField(
              initialValue: editState.username,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your username',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                ref.read(profileEditFormProvider((
                  widget.profile.username,
                  widget.profile.aboutMe,
                  widget.profile.isPrivateProfile,
                )).notifier).updateUsername(value);
              },
            ),
            const SizedBox(height: 16),

            // About me field
            TextField(
              initialValue: editState.aboutMe,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'About Me',
                hintText: 'Tell us about yourself',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                ref.read(profileEditFormProvider((
                  widget.profile.username,
                  widget.profile.aboutMe,
                  widget.profile.isPrivateProfile,
                )).notifier).updateAboutMe(value);
              },
            ),
            const SizedBox(height: 16),

            // Privacy toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Private Profile'),
                    Switch(
                      value: editState.isPrivateProfile,
                      onChanged: (value) {
                        ref.read(profileEditFormProvider((
                          widget.profile.username,
                          widget.profile.aboutMe,
                          widget.profile.isPrivateProfile,
                        )).notifier).togglePrivacy();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              editState.isPrivateProfile
                  ? 'Only you can see your profile'
                  : 'Everyone can see your profile',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            // Error message
            if (editState.error != null) ...[
              const SizedBox(height: 16),
              SnackBar(
                content: Text(editState.error!),
                backgroundColor: Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
