import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({SupabaseClient? client})
    : supabase = client ?? Supabase.instance.client;

  static const String mobileOAuthRedirectUrl = 'ysmamuseum://login-callback/';

  final SupabaseClient supabase;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Session? get currentSession => supabase.auth.currentSession;

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) {
    final cleanedName = _cleanDisplayName(fullName);

    return supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: mobileOAuthRedirectUrl,
      data: cleanedName.isEmpty ? null : _profileMetadata(cleanedName),
    );
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> resendSignupConfirmation({required String email}) async {
    await supabase.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: mobileOAuthRedirectUrl,
    );
  }

  Future<void> signInWithGoogle() async {
    final launched = await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : mobileOAuthRedirectUrl,
    );

    if (!launched) {
      throw const AuthFlowException(
        'Could not open Google sign-in. Check that Google auth is enabled in Supabase.',
      );
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final cleanedName = _cleanDisplayName(displayName);

    if (cleanedName.isEmpty) {
      return;
    }

    await supabase.auth.updateUser(
      UserAttributes(data: _profileMetadata(cleanedName)),
    );
  }

  Future<void> signOut() {
    return supabase.auth.signOut();
  }

  Map<String, String> _profileMetadata(String displayName) {
    return {
      'full_name': displayName,
      'name': displayName,
      'display_name': displayName,
    };
  }

  String _cleanDisplayName(String displayName) {
    return displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
