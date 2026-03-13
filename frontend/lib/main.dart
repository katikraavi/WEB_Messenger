import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:frontend/app.dart';
import 'package:frontend/core/services/api_client.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';

void main() async {
  // Initialize API client before running app
  await ApiClient.initialize();
  
  runApp(
    ProviderScope(
      child: provider_pkg.MultiProvider(
        providers: [
          provider_pkg.ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(),
          ),
        ],
        child: const MessengerApp(),
      ),
    ),
  );
}

