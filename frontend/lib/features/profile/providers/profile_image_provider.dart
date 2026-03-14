import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/profile_api_service.dart';
import '../utils/profile_logger.dart';

/// State for profile image upload
class ProfileImageState {
  final String? selectedImagePath;
  final double uploadProgress; // 0.0 to 1.0
  final bool isUploading;
  final String? error;
  final String? uploadedImageUrl;
  final DateTime? lastUploadTime; // For rapid-fire protection [T135]
  final int? bytesUploaded; // T142: Upload progress tracking
  final int? totalBytes; // T142: Upload progress tracking

  const ProfileImageState({
    this.selectedImagePath,
    this.uploadProgress = 0.0,
    this.isUploading = false,
    this.error,
    this.uploadedImageUrl,
    this.lastUploadTime,
    this.bytesUploaded,
    this.totalBytes,
  });

  ProfileImageState copyWith({
    String? selectedImagePath,
    double? uploadProgress,
    bool? isUploading,
    String? error,
    String? uploadedImageUrl,
    DateTime? lastUploadTime,
    int? bytesUploaded,
    int? totalBytes,
  }) =>
      ProfileImageState(
        selectedImagePath: selectedImagePath ?? this.selectedImagePath,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        isUploading: isUploading ?? this.isUploading,
        error: error,
        uploadedImageUrl: uploadedImageUrl ?? this.uploadedImageUrl,
        lastUploadTime: lastUploadTime ?? this.lastUploadTime,
        bytesUploaded: bytesUploaded ?? this.bytesUploaded,
        totalBytes: totalBytes ?? this.totalBytes,
      );

  void reset() {
    // Should be called via the notifier
  }
}

/// Notifier for profile image upload [Phase 11 - Edge Case Handling]
/// 
/// T136: Last write wins for concurrent edits
/// T148-T152: Edge case handling
class ProfileImageNotifier extends StateNotifier<ProfileImageState> {
  final ProfileApiService _apiService = ProfileApiService();

  ProfileImageNotifier() : super(const ProfileImageState());

  Future<void> selectImage(String imagePath) async {
    // T146: Null safety check for image path
    if (imagePath.isEmpty) {
      state = state.copyWith(error: 'Invalid image path');
      return;
    }
    state = state.copyWith(selectedImagePath: imagePath);
  }

  Future<void> uploadImage({String? token}) async {
    // T148: Edge case - no image selected
    if (state.selectedImagePath == null) {
      state = state.copyWith(error: 'No image selected');
      ProfileLogger.logError('uploadImage', 'No image selected');
      return;
    }

    // T135: Rapid-fire protection - ignore duplicate uploads within 1 second
    if (state.lastUploadTime != null) {
      final timeSinceLastUpload = DateTime.now().difference(state.lastUploadTime!);
      if (timeSinceLastUpload.inSeconds < 1) {
        ProfileLogger.logStateChange('uploadImage', 'Ignored duplicate upload (< 1s)');
        return;
      }
    }

    state = state.copyWith(
      isUploading: true,
      error: null,
      uploadProgress: 0.0,
      lastUploadTime: DateTime.now(),
    );

    try {
      // Create File object from path
      final imageFile = File(state.selectedImagePath!);

      // T146: Verify file exists before upload
      if (!await imageFile.exists()) {
        state = state.copyWith(
          isUploading: false,
          error: 'Image file not found', // Edge case T148
        );
        ProfileLogger.logError('uploadImage', 'File not found: ${state.selectedImagePath}');
        return;
      }

      // T141: Simulate progress updates
      // In a real implementation, the API would provide streaming progress
      state = state.copyWith(uploadProgress: 0.2);
      await Future.delayed(const Duration(milliseconds: 100));

      state = state.copyWith(uploadProgress: 0.5);
      await Future.delayed(const Duration(milliseconds: 100));

      // Call API to upload image
      ProfileLogger.logApiRequest('POST', '/api/profile/picture');
      final updatedProfile = await _apiService.uploadImage(imageFile, token: token);
      
      // T152: Handle invalid response from backend
      if (updatedProfile.profilePictureUrl == null) {
        state = state.copyWith(
          isUploading: false,
          error: 'Upload successful but invalid response from server',
        );
        ProfileLogger.logError('uploadImage', 'Invalid response: profilePictureUrl is null');
        return;
      }

      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        uploadedImageUrl: updatedProfile.profilePictureUrl,
        selectedImagePath: null,
        error: null,
      );
      ProfileLogger.logApiResponse('POST', '/api/profile/picture', 200);
    } on HttpException catch (e) {
      // Handle HTTP errors specifically
      state = state.copyWith(
        isUploading: false,
        error: e.message,
      );
      ProfileLogger.logError('uploadImage', 'HTTP Error: ${e.message}');
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: 'Upload failed: ${e.toString()}',
      );
      ProfileLogger.logError('uploadImage', e.toString());
    }
  }

  Future<void> deleteImage({String? token}) async {
    // T148: Edge case - no image to delete
    if (state.uploadedImageUrl == null) {
      state = state.copyWith(error: 'No image to delete');
      ProfileLogger.logError('deleteImage', 'No image to delete');
      return;
    }

    state = state.copyWith(isUploading: true, error: null);

    try {
      ProfileLogger.logApiRequest('DELETE', '/api/profile/picture');
      await _apiService.deleteImage(token: token);

      state = state.copyWith(
        isUploading: false,
        uploadedImageUrl: null,
        selectedImagePath: null,
        error: null,
      );
      ProfileLogger.logApiResponse('DELETE', '/api/profile/picture', 200);
    } on HttpException catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.message,
      );
      ProfileLogger.logError('deleteImage', 'HTTP Error: ${e.message}');
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: 'Delete failed: ${e.toString()}',
      );
      ProfileLogger.logError('deleteImage', e.toString());
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
