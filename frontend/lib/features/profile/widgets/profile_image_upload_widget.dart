import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../../../utils/copyable_error_widget.dart';
import '../providers/profile_image_provider.dart';
import '../services/image_picker_service.dart';
import '../widgets/image_picker_permissions_handler.dart';
import '../widgets/image_upload_progress_widget.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileImageUploadWidget extends ConsumerWidget {
  final String? currentImageUrl;

  const ProfileImageUploadWidget({
    this.currentImageUrl,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageState = ref.watch(profileImageProvider);

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
                child: imageState.selectedImagePath != null
                    ? ClipOval(
                  child: Image.asset(
                    imageState.selectedImagePath!,
                    fit: BoxFit.cover,
                  ),
                )
                    : imageState.uploadedImageUrl != null
                    ? ClipOval(
                  child: Image.network(
                    imageState.uploadedImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person, size: 70),
                  ),
                )
                    : currentImageUrl != null
                    ? ClipOval(
                  child: Image.network(
                    currentImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person, size: 70),
                  ),
                )
                    : const Icon(Icons.person, size: 70),
              ),
            ),
            // Remove button - only show if there's an uploaded image
            if (imageState.uploadedImageUrl != null ||
                currentImageUrl != null)
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
                      final authProvider = provider_pkg.Provider.of<AuthProvider>(context, listen: false);
                      final token = authProvider.token;
                      
                      await ref
                          .read(profileImageProvider.notifier)
                          .deleteImage(token: token);
                      if (context.mounted &&
                          imageState.error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Image deleted successfully!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showCopyableErrorSnackBar(context, 'Delete failed: $e');
                      }
                    }
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Image picker buttons
        // T138: Accessibility labels for gallery and camera buttons
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
                    final hasPermission = await ImagePickerPermissionsHandler
                        .requestGalleryPermission(context);
                    if (!hasPermission) {
                      return; // User denied permission
                    }

                    final image =
                    await ImagePickerService.pickImageFromGallery();
                    if (image != null) {
                      // Comprehensive validation with specific error messages
                      final validationError =
                          await ImagePickerService.validateImageComprehensive(image);
                      if (validationError != null) {
                        if (context.mounted) {
                          showCopyableErrorSnackBar(context, validationError.message);
                        }
                        return;
                      }
                      await ref
                          .read(profileImageProvider.notifier)
                          .selectImage(image.path);
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
                    // T133: Request camera permission before opening picker
                    final hasPermission = await ImagePickerPermissionsHandler
                        .requestCameraPermission(context);
                    if (!hasPermission) {
                      return; // User denied permission
                    }

                    final image =
                    await ImagePickerService.pickImageFromCamera();
                    if (image != null) {
                      // Comprehensive validation with specific error messages
                      final validationError =
                          await ImagePickerService.validateImageComprehensive(image);
                      if (validationError != null) {
                        if (context.mounted) {
                          showCopyableErrorSnackBar(context, validationError.message);
                        }
                        return;
                      }
                      await ref
                          .read(profileImageProvider.notifier)
                          .selectImage(image.path);
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
              final authProvider = provider_pkg.Provider.of<AuthProvider>(context, listen: false);
              final token = authProvider.token;
              
              await ref.read(profileImageProvider.notifier).uploadImage(token: token);
              if (context.mounted && imageState.error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image uploaded successfully!')),
                );
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
