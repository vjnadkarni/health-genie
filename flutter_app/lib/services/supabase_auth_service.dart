import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  factory SupabaseAuthService() => _instance;
  SupabaseAuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Get current user ID
  String? get currentUserId => currentUser?.id;

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
      );

      if (response.user != null) {
        // Create user profile
        await _createUserProfile(response.user!.id, email, fullName);
      }

      return response;
    } catch (e) {
      debugPrint('Sign up error: $e');
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

      if (response.user != null) {
        // Update last login
        await _updateLastLogin(response.user!.id);
      }

      return response;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  /// Sign in with Apple
  Future<AuthResponse> signInWithApple() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.healthgenie://login-callback/',
        scopes: 'email name',
      );

      return AuthResponse(user: currentUser);
    } catch (e) {
      debugPrint('Apple sign in error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.healthgenie://reset-password/',
      );
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  /// Update password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } catch (e) {
      debugPrint('Update password error: $e');
      rethrow;
    }
  }

  /// Create user profile in database
  Future<void> _createUserProfile(String userId, String email, String? fullName) async {
    try {
      await _supabase.from('user_profiles').upsert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'device_id': await _getDeviceId(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Create user profile error: $e');
    }
  }

  /// Update last login time
  Future<void> _updateLastLogin(String userId) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Update last login error: $e');
    }
  }

  /// Get device ID for tracking
  Future<String> _getDeviceId() async {
    // In production, use a proper device ID package
    // For now, return a placeholder
    return 'iphone_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Check if email exists
  Future<bool> emailExists(String email) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Check email exists error: $e');
      return false;
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Get user profile error: $e');
      return null;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    String? fullName,
    String? email,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (email != null) updates['email'] = email;

      await _supabase
          .from('user_profiles')
          .update(updates)
          .eq('id', userId);
    } catch (e) {
      debugPrint('Update user profile error: $e');
      rethrow;
    }
  }
}