import 'package:flutter/material.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/services/api_client.dart';

void main() async {
  // Initialize API client before running app
  await ApiClient.initialize();
  
  runApp(const MessengerApp());
}

