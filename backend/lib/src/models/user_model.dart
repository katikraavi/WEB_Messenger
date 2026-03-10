/// User Data Model
/// Represents a user in the system
/// TODO: Add encrypted fields per Constitution I (encryptedPasswordHash, etc.)

class UserModel {
  final String userId;
  final String username;
  final String email;
  // TODO: Add encrypted fields: encryptedPasswordHash, encryptedPhoneNumber
  
  UserModel({
    required this.userId,
    required this.username,
    required this.email,
  });
}
