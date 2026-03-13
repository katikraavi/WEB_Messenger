import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for profile image upload
class ProfileImageState {
  final String? selectedImagePath;
  final double uploadProgress; // 0.0 to 1.0
  final bool isUploading;
  final String? error;
  final String? uploadedImageUrl;

  const ProfileImageState({
    this.selectedImagePath,
    this.uploadProgress = 0.0,
    this.isUploading = false,
    this.error,
    this.uploadedImageUrl,
  });

  ProfileImageState copyWith({
    String? selectedImagePath,
    double? uploadProgress,
    bool? isUploading,
    String? error,
    String? uploadedImageUrl,
  }) =>
      ProfileImageState(
        selectedImagePath: selectedImagePath ?? this.selectedImagePath,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        isUploading: isUploading ?? this.isUploading,
        error: error,
        uploadedImageUrl: uploadedImageUrl ?? this.uploadedImageUrl,
      );

  void reset() {
    // Should be called via the notifier
  }
}

/// Notifier for profile image upload
class ProfileImageNotifier extends StateNotifier<ProfileImageState> {
  ProfileImageNotifier() : super(const ProfileImageState());

  Future<void> selectImage(String imagePath) async {
    state = state.copyWith(selectedImagePath: imagePath);
  }

  Future<void> uploadImage() async {
    if (state.selectedImagePath == null) {
      state = state.copyWith(error: 'No image selected');
      return;
    }

    state = state.copyWith(isUploading: true, error: null, uploadProgress: 0.0);

    try {
      // TODO: Call ProfileService.uploadImage()
      // Simulate upload progress
      for (int i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        state = state.copyWith(uploadProgress: i / 10);
      }

      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        uploadedImageUrl: '/uploads/profiles/mock-image.jpg',
        selectedImagePath: null,
      );
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.toString(),
      );
    }
  }

  void resetError() {
    state = state.copyWith(error: null);
  }

  void clearImage() {
    state = state.copyWith(
      selectedImagePath: null,
      uploadProgress: 0.0,
    );
  }
}

/// Riverpod provider for profile image upload
final profileImageProvider = StateNotifierProvider<ProfileImageNotifier, ProfileImageState>(
  (ref) => ProfileImageNotifier(),
);
