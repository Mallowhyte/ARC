/// Authentication Service
/// Handles user authentication with Supabase Auth

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Get current user ID
  String? get currentUserId => currentUser?.id;

  /// Get current user email
  String? get currentUserEmail => currentUser?.email;

  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      // Basic client-side validation to avoid pointless requests
      if (email.isEmpty) {
        throw Exception('Please enter an email address.');
      }
      if (!isValidEmail(email)) {
        throw Exception('Please enter a valid email address.');
      }
      if (!isValidPassword(password)) {
        throw Exception(
          'Password must be at least 8 characters with uppercase, lowercase, and numbers.',
        );
      }

      print('[AuthService] signUp: attempting for email=$email');

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName?.trim()},
      );

      print('[AuthService] signUp: got user id=${response.user?.id}');

      if (response.user != null) {
        // Create user profile in database (non-fatal if it fails)
        try {
          await _createUserProfile(
            userId: response.user!.id,
            email: email.trim(),
            fullName: fullName?.trim(),
          );
        } catch (profileError) {
          print(
            '[AuthService] signUp: error creating user profile: $profileError',
          );
        }
      }

      return response;
    } on AuthException catch (e) {
      // Map common Supabase auth errors to clearer messages that the UI can show
      final msg = e.message.toLowerCase();
      print('[AuthService] AuthException during signUp: ${e.message}');

      if (msg.contains('already registered') ||
          msg.contains('user already exists')) {
        throw Exception(
          'This email is already registered. Please login instead.',
        );
      }
      if (msg.contains('invalid email') ||
          msg.contains('email address is invalid')) {
        throw Exception('Please enter a valid email address.');
      }
      if (msg.contains('password')) {
        throw Exception(
          'Password must be at least 8 characters with uppercase, lowercase, and numbers.',
        );
      }

      // Fallback: surface Supabase message
      throw Exception(e.message);
    } catch (e) {
      print('[AuthService] Unexpected error during signUp: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('No user returned after sign in');
      }

      // User can log in even if email is not verified
      // We'll handle feature gating in the UI instead
      return response;
    } on AuthException catch (e) {
      // Re-throw auth-specific errors with clear messages
      rethrow;
    } catch (e) {
      // For other errors, provide a generic message
      throw Exception(
        'Failed to sign in. Please check your credentials and try again.',
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  /// Update user password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update user profile
  Future<UserResponse> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['full_name'] = fullName;
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;

      return await _supabase.auth.updateUser(UserAttributes(data: data));
    } catch (e) {
      rethrow;
    }
  }

  /// Get user profile data
  Map<String, dynamic>? get userMetadata => currentUser?.userMetadata;

  /// Get user full name
  String? get userFullName => userMetadata?['full_name'];

  /// Create user profile in database
  Future<void> _createUserProfile({
    required String userId,
    required String email,
    String? fullName,
  }) async {
    try {
      print(
        '[AuthService] _createUserProfile: inserting user profile for $email',
      );
      await _supabase.from('users').insert({
        'id': userId,
        'email': email,
        'full_name': fullName ?? email.split('@')[0],
        'created_at': DateTime.now().toIso8601String(),
      });
      print('[AuthService] _createUserProfile: profile insert succeeded');
    } catch (e) {
      // Profile might already exist or RLS might block insert; log but do not fail sign-up
      print('[AuthService] _createUserProfile error (non-fatal): $e');
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Check if email is verified
  bool get isEmailVerified {
    final user = currentUser;
    if (user == null) return false;
    return user.emailConfirmedAt != null;
  }

  /// Verify email with OTP (6-digit PIN code)
  Future<bool> verifyEmailWithOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: token,
      );

      return response.user != null;
    } catch (e) {
      print('OTP verification error: $e');
      return false;
    }
  }

  /// Resend verification email with OTP
  Future<void> resendVerificationEmail([String? email]) async {
    try {
      final emailToUse = email ?? currentUserEmail;
      if (emailToUse == null) throw Exception('No user email found');

      await _supabase.auth.resend(type: OtpType.signup, email: emailToUse);
    } catch (e) {
      rethrow;
    }
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate password strength
  static bool isValidPassword(String password) {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  /// Get password strength message
  static String getPasswordStrengthMessage(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number';
    }
    return 'Password is valid';
  }
}
