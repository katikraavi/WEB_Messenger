import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/models/user.dart';

class ProfileService {
  static const String baseUrl = 'http://localhost:8081';
  final String? authToken;

  ProfileService({this.authToken});

  /// Get user profile
  Future<User?> getProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile/view/$userId'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else if (response.statusCode == 403) {
        throw Exception('Profile is private');
      } else if (response.statusCode == 404) {
        throw Exception('Profile not found');
      } else {
        throw Exception('Failed to fetch profile: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update user profile
  Future<User?> updateProfile({
    required String userId,
    String? username,
    String? aboutMe,
    bool? isPrivateProfile,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/profile/edit'),
        headers: _headers(),
        body: jsonEncode({
          if (username != null) 'username': username,
          if (aboutMe != null) 'aboutMe': aboutMe,
          if (isPrivateProfile != null) 'isPrivateProfile': isPrivateProfile,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception('Update failed: ${errorBody['errors'] ?? response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Upload profile picture
  Future<String?> uploadProfilePicture(String filePath) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/profile/picture/upload'),
        headers: _headers(),
        // In real app, would use MultipartRequest for file upload
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['imageUrl'] as String?;
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete profile picture
  Future<void> deleteProfilePicture() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/profile/picture'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Delete failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };
}
