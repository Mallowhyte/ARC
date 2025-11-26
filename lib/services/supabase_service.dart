/// Supabase Service
/// Handles Supabase authentication and database operations

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  /// Get Supabase client
  SupabaseClient get client {
    // Relies on Supabase.initialize being called in main.dart
    return Supabase.instance.client;
  }

  /// Get current user
  User? get currentUser => client.auth.currentUser;

  /// Get current user ID
  String? get currentUserId => currentUser?.id;

  /// Sign in with email and password
  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  /// Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;
}
