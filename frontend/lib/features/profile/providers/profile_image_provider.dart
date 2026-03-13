import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/profile_api_service.dart';

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
  final ProfileApiService _apiService = ProfileApiService();

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
      // Create File object from path
      final imageFile = File(state.selectedImagePath!);

      // Verify file exists
      if (!await imageFile.exists()) {
        state = state.copyWith(
          isUploading: false,
          error: 'Image file not found',
        );
        return;
      }

      // Simulate progress updates
      // In a real implementation, the API would provide streaming progress
      state = state.copyWith(uploadProgress: 0.2);
      await Future.delayed(const Duration(milliseconds: 100));

      state = state.copyWith(uploadProgress: 0.5);
      await Future.delayed(const Duration(milliseconds: 100));

      // Call API to upload image
      final updatedProfile = await _apiService.uploadImage(imageFile);

      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        uploadedImageUrl: updatedProfile.profilePictureUrl,
        selectedImagePath: null,
        error: null,
      );
    } on HttpException catch (e) {
      // Handle HTTP errors specifically
      state = state.copyWith(
        isUploading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: 'Upload failed: ${e.toString()}',
      );
    }
  }

  Future<void> deleteImage() async {
    if (state.uploadedImageUrl == null) {
      state = state.copyWith(error: 'No image to delete');
      return;
    }

    state = state.copyWith(isUploading: true, error: null);

    try {
      await _apiService.deleteImage();

      state = state.copyWith(
        isUploading: false,
        uploadedImageUrl: null,
        selectedImagePath: null,
        error: null,
      );
    } on HttpException catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: 'Delete failed: ${e.toString()}',
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
