import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/user_auth_service.dart';
import '../services/auth_exception.dart';

/// Authentication endpoint
/// 
/// Handles user authentication requests: registration, login, session validation, and logout
/// 
/// Endpoints:
/// - POST /auth/register - New user registration
/// - POST /auth/login - User login with email/password
/// - GET /auth/me - Session validation (protected)
/// - POST /auth/logout - User logout (protected)
class AuthEndpoint {
  final UserAuthService _authService;

  AuthEndpoint({required UserAuthService authService}) : _authService = authService;

  /// Handle POST /auth/register
  /// Request body: { "email": "...", "username": "...", "password": "...", "full_name": "..." }
  /// 
  /// Returns:
  /// - 201: User created successfully with user info
  /// - 400: Validation error (bad email, weak password, missing fields)
  /// - 409: Email or username already registered
  /// - 500: Server error
  Future<Response> register(Request request) async {
    try {
      // Parse request body
      final bodyString = await request.readAsString();
      if (bodyString.isEmpty) {
        return Response(400,
          body: jsonEncode({
            'error': 'Request body is required',
            'details': ['Email, username, and password fields are required']
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final Map<String, dynamic> body = jsonDecode(bodyString);

      // Validate required fields
      final email = body['email'] as String?;
      final username = body['username'] as String?;
      final password = body['password'] as String?;
      final fullName = body['full_name'] as String?;

      if (email == null || email.isEmpty) {
        return Response(400,
          body: jsonEncode({
            'error': 'Password validation failed',
            'details': ['Email is required']
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (username == null || username.isEmpty) {
        return Response(400,
          body: jsonEncode({
            'error': 'Validation failed',
            'details': ['Username is required']
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (password == null || password.isEmpty) {
        return Response(400,
          body: jsonEncode({
            'error': 'Validation failed',
            'details': ['Password is required']
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Call service to register user
      final authResult = await _authService.registerUser(
        email,
        username,
        password,
        fullName: fullName,
      );

      return Response(201,
        body: jsonEncode({
          'user_id': authResult.userId,
          'email': authResult.email,
          'username': authResult.username,
          'message': 'Account created successfully'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AuthException catch (e) {
      // Specific error handling for auth exceptions
      if (e.code == 'weak_password') {
        return Response(400,
          body: jsonEncode({
            'error': 'Password validation failed',
            'details': e.message.split(': ').skip(1).toList().isNotEmpty 
              ? e.message.split(': ').skip(1).toList()
              : ['Password does not meet strength requirements']
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else if (e.code == 'user_exists') {
        if (e.message.contains('Email')) {
          return Response(409,
            body: jsonEncode({'error': 'Email already registered'}),
            headers: {'Content-Type': 'application/json'},
          );
        } else {
          return Response(409,
            body: jsonEncode({'error': 'Username already taken'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      } else if (e.code == 'invalid_email_format') {
        return Response(400,
          body: jsonEncode({
            'error': 'Validation failed',
            'details': ['Invalid email format']
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(500,
          body: jsonEncode({
            'error': 'Server error - please try again later'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('[ERROR] Unexpected error in register: $e');
      return Response(500,
        body: jsonEncode({
          'error': 'Server error - please try again later'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle POST /auth/login
  /// Request body: { "email": "...", "password": "..." }
  /// 
  /// Returns:
  /// - 200: Login successful with token
  /// - 400: Validation error (missing fields)
  /// - 401: Invalid credentials
  /// - 429: Rate limit exceeded
  /// - 500: Server error
  Future<Response> login(Request request) async {
    try {
      // Parse request body
      final bodyString = await request.readAsString();
      if (bodyString.isEmpty) {
        return Response(400,
          body: jsonEncode({
            'error': 'Request body is required',
            'details': ['Email and password are required']
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final Map<String, dynamic> body = jsonDecode(bodyString);

      // Validate required fields
      final email = body['email'] as String?;
      final password = body['password'] as String?;

      if (email == null || email.isEmpty) {
        return Response(400,
          body: jsonEncode({
            'error': 'Validation failed',
            'details': ['Email is required']
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (password == null || password.isEmpty) {
        return Response(400,
          body: jsonEncode({
            'error': 'Validation failed',
            'details': ['Password is required']
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Call service to authenticate user
      final authResult = await _authService.authenticateUser(email, password);

      return Response.ok(
        jsonEncode({
          'user_id': authResult.userId,
          'email': authResult.email,
          'username': authResult.username,
          'token': authResult.token
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AuthException catch (e) {
      if (e.code == 'invalid_credentials') {
        return Response(401,
          body: jsonEncode({'error': 'Invalid email or password'}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(500,
          body: jsonEncode({
            'error': 'Server error - please try again later'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('[ERROR] Unexpected error in login: $e');
      return Response(500,
        body: jsonEncode({
          'error': 'Server error - please try again later'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle GET /auth/me (protected endpoint)
  /// 
  /// Returns:
  /// - 200: User data with authentication status
  /// - 401: Invalid or missing token
  Future<Response> validateSession(Request request) async {
    try {
      // Extract user info from context (set by JWT middleware)
      final userId = request.context['user_id'] as String?;
      final email = request.context['user_email'] as String?;

      if (userId == null || email == null) {
        return Response(401,
          body: jsonEncode({'error': 'Unauthorized'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'user_id': userId,
          'email': email,
          'is_authenticated': true
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('[ERROR] Error in validateSession: $e');
      return Response(500,
        body: jsonEncode({
          'error': 'Server error - please try again later'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle POST /auth/logout (protected endpoint)
  /// 
  /// Returns:
  /// - 200: Logout successful
  /// - 401: Invalid or missing token
  Future<Response> logout(Request request) async {
    try {
      // Extract user info from context (set by JWT middleware)
      final userId = request.context['user_id'] as String?;

      if (userId == null) {
        return Response(401,
          body: jsonEncode({'error': 'Unauthorized'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Log logout
      print('[AUTH] User logout: userId=$userId');

      return Response.ok(
        jsonEncode({'message': 'Logged out successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('[ERROR] Error in logout: $e');
      return Response(500,
        body: jsonEncode({
          'error': 'Server error - please try again later'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
