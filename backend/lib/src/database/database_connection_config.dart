import 'dart:io';

class DatabaseConnectionConfig {
  DatabaseConnectionConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.requireSsl,
    this.databaseUrl,
  });

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final bool requireSsl;
  final String? databaseUrl;

  factory DatabaseConnectionConfig.fromEnvironment(
    Map<String, String> environment,
  ) {
    final databaseUrl = environment['DATABASE_URL'];
    final explicitSsl = _parseOptionalBool(environment['DATABASE_SSL']);

    if (databaseUrl != null && databaseUrl.isNotEmpty) {
      final uri = Uri.parse(databaseUrl);
      final credentials = _parseUserInfo(uri.userInfo);

      return DatabaseConnectionConfig(
        host: uri.host.isEmpty
            ? (environment['DATABASE_HOST'] ?? 'postgres')
            : uri.host,
        port: uri.hasPort ? uri.port : 5432,
        database: uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : (environment['DATABASE_NAME'] ?? 'messenger_db'),
        username: credentials.$1.isNotEmpty
            ? credentials.$1
            : (environment['DATABASE_USER'] ?? 'messenger_user'),
        password: credentials.$2.isNotEmpty
            ? credentials.$2
            : (environment['DATABASE_PASSWORD'] ?? 'messenger_password'),
        requireSsl: explicitSsl ?? _requiresSsl(uri),
        databaseUrl: databaseUrl,
      );
    }

    return DatabaseConnectionConfig(
      host: environment['DATABASE_HOST'] ?? 'postgres',
      port: int.tryParse(environment['DATABASE_PORT'] ?? '') ?? 5432,
      database: environment['DATABASE_NAME'] ?? 'messenger_db',
      username: environment['DATABASE_USER'] ?? 'messenger_user',
      password: environment['DATABASE_PASSWORD'] ?? 'messenger_password',
      requireSsl: explicitSsl ?? false,
    );
  }

  String get maskedDescription {
    if (databaseUrl != null && databaseUrl!.isNotEmpty) {
      return _maskUrl(databaseUrl!);
    }

    return 'postgresql://$username:***@$host:$port/$database';
  }

  static bool _requiresSsl(Uri uri) {
    final sslMode = uri.queryParameters['sslmode']?.toLowerCase();
    return switch (sslMode) {
      'require' || 'verify-ca' || 'verify-full' => true,
      'disable' => false,
      _ => false,
    };
  }

  static (String, String) _parseUserInfo(String userInfo) {
    if (userInfo.isEmpty) {
      return ('', '');
    }

    final separatorIndex = userInfo.indexOf(':');
    if (separatorIndex == -1) {
      return (Uri.decodeComponent(userInfo), '');
    }

    final username = Uri.decodeComponent(userInfo.substring(0, separatorIndex));
    final password =
        Uri.decodeComponent(userInfo.substring(separatorIndex + 1));
    return (username, password);
  }

  static bool? _parseOptionalBool(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    switch (value.toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'on':
        return true;
      case '0':
      case 'false':
      case 'no':
      case 'off':
        return false;
      default:
        stderr.writeln(
          '[WARNING] Ignoring unrecognized DATABASE_SSL value: $value',
        );
        return null;
    }
  }

  static String _maskUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }

    final credentials = _parseUserInfo(uri.userInfo);
    if (credentials.$1.isEmpty) {
      return url;
    }

    final maskedUserInfo =
        credentials.$2.isEmpty ? credentials.$1 : '${credentials.$1}:***';
    return uri.replace(userInfo: maskedUserInfo).toString();
  }
}
