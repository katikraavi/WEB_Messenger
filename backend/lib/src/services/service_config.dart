import 'encryption_service.dart';

/// Global service configuration for request handlers
/// Initialized once on server startup
class ServiceConfig {
  static late EncryptionService encryptionService;
  
  /// Initialize service config (call once from main())
  static void initialize(EncryptionService encryption) {
    encryptionService = encryption;
  }
}
