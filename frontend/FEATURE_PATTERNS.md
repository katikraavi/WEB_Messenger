# Frontend Feature Modules

## Structure

Frontend follows a feature-based architecture with independent, testable modules:

```
frontend/lib/
├── features/
│   ├── auth/         # Authentication feature
│   │   ├── screens/  # Auth screens (login, register, reset password)
│   │   ├── widgets/  # Auth-specific widgets
│   │   ├── models/   # Auth data models
│   │   └── providers/ # State management (Riverpod, Provider, etc.)
│   │
│   ├── profile/      # User profile feature
│   ├── chat/         # Messaging feature
│   └── invites/      # Friend invite feature
│
└── core/            # Shared utilities
    ├── models/      # Shared data models
    ├── services/    # Core services (API client, etc.)
    ├── widgets/     # Reusable widgets
    ├── utils/       # Helpers and constants
    └── config/      # Application configuration
```

## Creating a New Feature

When creating a new feature (e.g., settings):

1. **Create directory**: `frontend/lib/features/settings/`

2. **Create subdirectories**:
   ```bash
   mkdir -p frontend/lib/features/settings/{screens,widgets,models,providers}
   ```

3. **Create main screen**:
   ```dart
   // frontend/lib/features/settings/screens/settings_screen.dart
   class SettingsScreen extends StatefulWidget {
     const SettingsScreen({super.key});

     @override
     State<SettingsScreen> createState() => _SettingsScreenState();
   }

   class _SettingsScreenState extends State<SettingsScreen> {
     @override
     Widget build(BuildContext context) {
       return Scaffold(
         appBar: AppBar(title: const Text('Settings')),
         body: ListView(children: [
           // Settings items
        ]),
       );
     }
   }
   ```

4. **Export from feature**: `frontend/lib/features/settings/main.dart`:
   ```dart
   export 'screens/settings_screen.dart';
   export 'models/settings_model.dart';
   ```

5. **Add to main app navigation** in `app.dart`:
   ```dart
   '/settings': (context) => const SettingsScreen(),
   ```

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| File | snake_case.dart | user_profile_screen.dart |
| Class | PascalCase | UserProfileScreen |
| Widget | PascalCase | UserAvatarWidget |
| Function | camelCase | getUserData() |
| Variable | camelCase | currentUser |
| Constant | camelCase or UPPER_CASE | appTitle or APP_TITLE |

## State Management

Choose one state management solution for the entire app:

- **Riverpod** (recommended): `flutter pub add riverpod flutter_riverpod`
- **Provider**: `flutter pub add provider`
- **Bloc**: `flutter pub add bloc flutter_bloc`

Example with Riverpod:
```dart
final userProvider = FutureProvider((ref) async {
  return await ApiClient.get('/user');
});

class UserProfile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    // ...
  }
}
```

## Code Organization

- Keep screens simple and focused on UI layout
- Move business logic to providers/controllers
- Keep components small and reusable
- Use composition over inheritance

Related: [API Client Setup](../core/services/api_client.dart) | [core/config](../core/config/)
