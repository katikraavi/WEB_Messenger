import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../../../utils/copyable_error_widget.dart';
import '../../../core/constants/asset_constants.dart';
import '../providers/profile_image_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/profile_form_state_provider.dart';
import '../providers/profile_cache_invalidator.dart';
import '../services/image_picker_service.dart';
import '../widgets/image_picker_permissions_handler.dart';
import '../widgets/image_upload_progress_widget.dart';
import '../widgets/cached_profile_image.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chats/providers/user_profile_provider.dart' as chats_profile_provider;

class ProfileImageUploadWidget extends ConsumerWidget {
  final String? currentImageUrl;
  final String? userId;

  const ProfileImageUploadWidget({this.currentImageUrl, this.userId, Key? key})
    : super(key: key);

  /// Build default profile picture with asset fallback
  Widget _buildDefaultProfilePicture() {
    return ClipOval(
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Image.asset(
            AssetConstants.defaultProfilePicture,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
          const Center(
            child: Icon(Icons.person, size: 70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AuthProvider? authProvider;
    try {
      authProvider = provider_pkg.Provider.of<AuthProvider?>(
        context,
        listen: false,
      );
    } catch (_) {
      authProvider = null;
    }
    final token = authProvider?.token;
    final imageState = ref.watch(profileImageProvider);

    // Watch the updated profile to display newly uploaded image URL
    final userProfileAsync = userId != null && token != null
        ? ref.watch(userProfileWithTokenProvider((userId!, token)))
        : null;

    return Column(
      children: [
        // Profile picture preview
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
                border: Border.all(color: Colors.grey[400]!, width: 2),
              ),
              child: Center(
                child: imageState.selectedImageBytes != null
                    ? ClipOval(
                        child: Image.memory(
                          imageState.selectedImageBytes!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : (!kIsWeb && imageState.selectedImagePath != null)
                    ? ClipOval(
                        child: Image.file(
                          File(imageState.selectedImagePath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : imageState.uploadedImageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          imageState.uploadedImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultProfilePicture();
                          },
                        ),
                      )
                    // After refresh, check if profile has updated image URL
                    : (userProfileAsync?.hasValue ?? false) &&
                          (userProfileAsync!
                                  .value!
                                  .profilePictureUrl
                                  ?.isNotEmpty ??
                              false) &&
                          userProfileAsync!.value!.profilePictureUrl !=
                              currentImageUrl
                    ? ClipOval(
                        child: Image.network(
                          userProfileAsync!.value!.profilePictureUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultProfilePicture();
                          },
                        ),
                      )
                    : currentImageUrl != null && currentImageUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          currentImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultProfilePicture();
                          },
                        ),
                      )
                    : _buildDefaultProfilePicture(),
              ),
            ),
            // Remove button - only show if there's an uploaded image
            if (imageState.uploadedImageUrl != null ||
                ((userProfileAsync?.hasValue ?? false) &&
                    (userProfileAsync!.value!.profilePictureUrl?.isNotEmpty ??
                        false)) ||
                (currentImageUrl != null && currentImageUrl!.isNotEmpty))
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  iconSize: 20,
                  onPressed: imageState.isUploading
                      ? null
                      : () async {
                          try {
                            await ref
                                .read(profileImageProvider.notifier)
                                .deleteImage(token: token);

                            // Refresh profile after successful delete to update image URL
                            final deletedImageState = ref.read(
                              profileImageProvider,
                            );
                            if (context.mounted &&
                              deletedImageState.error == null &&
                              userId != null &&
                              token != null) {
                              
                              // Clear image cache when deleting
                              if (currentImageUrl != null && currentImageUrl!.isNotEmpty) {
                                await ProfileImageCacheManager.clearImageCache(currentImageUrl!);
                              }
                              
                              // Mark form as dirty so SAVE button is enabled (image was deleted)
                              try {
                                  final profileAsync = ref.read(
                                    userProfileWithTokenProvider((
                                      userId!,
                                      token,
                                    )),
                                  );
                                if (profileAsync.hasValue) {
                                  final userProfile = profileAsync.value!;
                                  ref
                                      .read(
                                        profileFormStateProvider(
                                          userProfile,
                                        ).notifier,
                                      )
                                      .markImageChanged();
                                }
                              } catch (e) {
                                // If we can't mark it as dirty, continue anyway
                              }

                              // Invalidate all profile caches globally to update avatars everywhere
                              invalidateUserProfileCache(ref, userId!);

                              // Also invalidate the chats module's profile provider so chat list avatars update
                              ref.invalidate(
                                chats_profile_provider.userProfileProvider((userId!, token!)),
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Image deleted successfully!'),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showCopyableErrorSnackBar(
                                context,
                                'Delete failed: $e',
                              );
                            }
                          }
                        },
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Image picker buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Tooltip(
              message: 'Pick image from gallery',
              child: ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                onPressed: imageState.isUploading
                    ? null
                    : () async {
                        try {
                          // T133: Request gallery permission before opening picker
                          final hasPermission =
                              await ImagePickerPermissionsHandler.requestGalleryPermission(
                                context,
                              );
                          if (!hasPermission) {
                            return; // User denied permission
                          }

                          final image =
                              await ImagePickerService.pickImageFromGallery();
                          if (image != null) {
                            // Comprehensive validation with specific error messages
                            final validationError =
                                await ImagePickerService.validateImageComprehensive(
                                  image,
                                );
                            if (validationError != null) {
                              if (context.mounted) {
                                showCopyableErrorSnackBar(
                                  context,
                                  validationError.message,
                                );
                              }
                              return;
                            }
                            await ref
                                .read(profileImageProvider.notifier)
                                .selectImage(
                                  image.path,
                                  imageBytes: await image.readAsBytes(),
                                  imageName: image.name,
                                );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showCopyableErrorSnackBar(context, 'Error: $e');
                          }
                        }
                      },
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Take photo with camera',
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                onPressed: imageState.isUploading
                    ? null
                    : () async {
                        try {
                          final hasPermission =
                              await ImagePickerPermissionsHandler.requestCameraPermission(
                                context,
                              );
                          if (!hasPermission) {
                            return;
                          }

                          final image =
                              await ImagePickerService.pickImageFromCamera();
                          if (image != null) {
                            final validationError =
                                await ImagePickerService.validateImageComprehensive(
                                  image,
                                );
                            if (validationError != null) {
                              if (context.mounted) {
                                showCopyableErrorSnackBar(
                                  context,
                                  validationError.message,
                                );
                              }
                              return;
                            }
                            await ref
                                .read(profileImageProvider.notifier)
                                .selectImage(
                                  image.path,
                                  imageBytes: await image.readAsBytes(),
                                  imageName: image.name,
                                );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showCopyableErrorSnackBar(context, 'Error: $e');
                          }
                        }
                      },
              ),
            ),
          ],
        ),

        // Info about automatic compression
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '💡 Tip: Images up to 10MB are supported. Images between 5-10MB will be automatically compressed for optimal quality while reducing file size.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),

        // Upload progress
        // T142: Enhanced image upload progress display
        if (imageState.isUploading) ...[
          const SizedBox(height: 16),
          ImageUploadProgressWidget(
            progress: imageState.uploadProgress,
            bytesUploaded: imageState.bytesUploaded ?? 0,
            totalBytes: imageState.totalBytes ?? 0,
            displayFormat: 'simple',
            onCancel: null, // Could add cancel functionality later
          ),
        ],

        // Upload button
        if (imageState.selectedImagePath != null &&
            !imageState.isUploading) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Upload'),
            onPressed: () async {
              await ref
                  .read(profileImageProvider.notifier)
                  .uploadImage(token: token);

              // Check updated state after upload completes
              final updatedImageState = ref.read(profileImageProvider);

              // Refresh profile after successful upload to show new image URL
              if (context.mounted &&
                  updatedImageState.error == null &&
                  userId != null &&
                  token != null) {
                
                // Clear old image cache for the user
                if (currentImageUrl != null && currentImageUrl!.isNotEmpty) {
                  await ProfileImageCacheManager.clearImageCache(currentImageUrl!);
                }
                
                // Clear new image cache to force reload
                if (updatedImageState.uploadedImageUrl != null) {
                  await ProfileImageCacheManager.clearImageCache(updatedImageState.uploadedImageUrl!);
                }
                
                // Mark form as dirty so SAVE button is enabled (image has changed)
                try {
                  final profileAsync = ref.read(
                    userProfileWithTokenProvider((userId!, token)),
                  );
                  if (profileAsync.hasValue) {
                    final userProfile = profileAsync.value!;
                    ref
                        .read(profileFormStateProvider(userProfile).notifier)
                        .markImageChanged();
                  }
                } catch (e) {
                  // If we can't mark it as dirty, continue anyway
                }

                // Invalidate all profile caches globally to update avatars everywhere
                invalidateUserProfileCache(ref, userId!);
                
                // Also invalidate in chats module for chat list avatars
                ref.invalidate(
                  chats_profile_provider.userProfileProvider((userId!, token!)),
                );

                // Update local profile cache for offline support
                try {
                  final cachedProfile = await ref.watch(
                    userProfileWithTokenProvider((userId!, token)).future,
                  );
                  // Cache will be handled automatically by profile cache service
                } catch (e) {
                  // Ignore cache update failures
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Image uploaded successfully!'),
                    ),
                  );
                }
              }
            },
          ),
        ],

        // Error message
        if (imageState.error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[100],
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              imageState.error!,
              style: TextStyle(color: Colors.red[800]),
            ),
          ),
        ],
      ],
    );
  }
}
