import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery
  static Future<XFile?> pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      return pickedFile;
    } catch (e) {
      rethrow;
    }
  }

  /// Pick image from camera
  static Future<XFile?> pickImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      return pickedFile;
    } catch (e) {
      rethrow;
    }
  }

  /// Validate image locally before upload
  static String? validateImage(XFile file) {
    const maxSizeBytes = 5242880; // 5MB

    // Check file extension
    final fileName = file.name.toLowerCase();
    if (!fileName.endsWith('.jpg') &&
        !fileName.endsWith('.jpeg') &&
        !fileName.endsWith('.png')) {
      return 'Only JPEG and PNG formats are supported';
    }

    // Note: In production, would also check file size here by reading file bytes
    return null; // Valid
  }
}
