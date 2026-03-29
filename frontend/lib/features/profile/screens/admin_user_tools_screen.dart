import 'package:flutter/material.dart';
import 'package:frontend/features/profile/screens/profile_view_screen.dart';

class AdminUserToolsScreen extends StatelessWidget {
  const AdminUserToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Tools')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720),
            child: ManualUserDeleteSection(),
          ),
        ),
      ),
    );
  }
}
