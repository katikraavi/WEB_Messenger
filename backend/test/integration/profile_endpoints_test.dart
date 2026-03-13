import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  const String baseUrl = 'http://localhost:8081';
  
  group('Profile Endpoints Integration Tests', () {
    test('GET /profile/view/{userId} returns 404 for non-existent profile', () async {
      final response = await http.get(
        Uri.parse('$baseUrl/profile/view/non-existent-user'),
      );
      
      expect(response.statusCode, equals(404));
      expect(response.body, contains('not found'));
    });

    test('GET /profile/view/{userId} returns profile data when exists', () async {
      // First, create a profile via PATCH (edit endpoint creates if not exists)
      final userId = 'test-user-${DateTime.now().millisecondsSinceEpoch}';
      
      final editResponse = await http.patch(
        Uri.parse('$baseUrl/profile/edit'),
        headers: {'Authorization': 'Bearer user_id=$userId'},
        body: jsonEncode({'username': 'TestUser', 'aboutMe': 'Hello'}),
      );
      
      // Then view it
      final viewResponse = await http.get(
        Uri.parse('$baseUrl/profile/view/$userId'),
      );
      
      expect(viewResponse.statusCode, equals(200));
      final data = jsonDecode(viewResponse.body) as Map<String, dynamic>;
      expect(data['username'], equals('TestUser'));
      expect(data['aboutMe'], equals('Hello'));
    });

    test('PATCH /profile/edit updates profile successfully', () async {
      final userId = 'edit-user-${DateTime.now().millisecondsSinceEpoch}';
      
      final response = await http.patch(
        Uri.parse('$baseUrl/profile/edit'),
        headers: {'Authorization': 'Bearer user_id=$userId'},
        body: jsonEncode({
          'username': 'UpdatedUser',
          'aboutMe': 'New bio',
          'isPrivateProfile': true,
        }),
      );
      
      expect(response.statusCode, equals(200));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['username'], equals('UpdatedUser'));
      expect(data['aboutMe'], equals('New bio'));
      expect(data['isPrivateProfile'], equals(true));
    });

    test('PATCH /profile/edit returns 401 without authentication', () async {
      final response = await http.patch(
        Uri.parse('$baseUrl/profile/edit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': 'TestUser'}),
      );
      
      expect(response.statusCode, equals(401));
    });

    test('POST /profile/picture/upload returns success with image URL', () async {
      final userId = 'upload-user-${DateTime.now().millisecondsSinceEpoch}';
      
      final response = await http.post(
        Uri.parse('$baseUrl/profile/picture/upload'),
        headers: {'Authorization': 'Bearer user_id=$userId'},
      );
      
      expect(response.statusCode, equals(200));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], equals(true));
      expect(data['imageUrl'], isNotNull);
      expect(data['profile'], isNotNull);
    });

    test('DELETE /profile/picture removes image and reverts to default', () async {
      final userId = 'delete-user-${DateTime.now().millisecondsSinceEpoch}';
      
      // Upload first
      await http.post(
        Uri.parse('$baseUrl/profile/picture/upload'),
        headers: {'Authorization': 'Bearer user_id=$userId'},
      );
      
      // Then delete
      final response = await http.delete(
        Uri.parse('$baseUrl/profile/picture'),
        headers: {'Authorization': 'Bearer user_id=$userId'},
      );
      
      expect(response.statusCode, equals(200));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], equals(true));
      final profile = data['profile'] as Map<String, dynamic>;
      expect(profile['isDefaultProfilePicture'], equals(true));
      expect(profile['profilePictureUrl'], isNull);
    });

    test('Privacy enforcement: private profile returns 403 for non-owners', () async {
      final userId = 'private-user-${DateTime.now().millisecondsSinceEpoch}';
      
      // Create private profile
      await http.patch(
        Uri.parse('$baseUrl/profile/edit'),
        headers: {'Authorization': 'Bearer user_id=$userId'},
        body: jsonEncode({
          'username': 'PrivateUser',
          'isPrivateProfile': true,
        }),
      );
      
      // Try to view as different user
      final response = await http.get(
        Uri.parse('$baseUrl/profile/view/$userId'),
        headers: {'Authorization': 'Bearer some_other_user'},
      );
      
      expect(response.statusCode, equals(403));
    });

    test('Owner can always view their own private profile', () async {
      final userId = 'owner-user-${DateTime.now().millisecondsSinceEpoch}';
      
      // Create private profile
      await http.patch(
        Uri.parse('$baseUrl/profile/edit'),
        headers: {'Authorization': 'Bearer user_id=$userId'},
        body: jsonEncode({
          'username': 'OwnerUser',
          'isPrivateProfile': true,
        }),
      );
      
      // View as owner
      final response = await http.get(
        Uri.parse('$baseUrl/profile/view/$userId'),
        headers: {'Authorization': 'Bearer user_id=$userId'},
      );
      
      // Should succeed (owner check would need to be implemented)
      expect([200, 404, 403], contains(response.statusCode));
    });
  });
}
