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

  String? get _authRedirectUrl {
    if (!kIsWeb) {
      return mobileOAuthRedirectUrl;
    }

    final baseUri = Uri.base;

    if (baseUri.scheme == 'http' || baseUri.scheme == 'https') {
      return baseUri.origin;
    }

    return null;
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) {
    final cleanedName = _cleanDisplayName(fullName);

    return supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _authRedirectUrl,
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
      emailRedirectTo: _authRedirectUrl,
    );
  }

  Future<void> signInWithGoogle() async {
    final launched = await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _authRedirectUrl,
    );

    if (!launched) {
      throw const AuthFlowException(
        'Could not open Google sign-in. Check that Google auth is enabled in Supabase.',
      );
    }
  }

  Future<void> updatePasswordForCurrentUser({
    required String password,
    required String fullName,
  }) async {
    final cleanedName = _cleanDisplayName(fullName);

    await supabase.auth.updateUser(
      UserAttributes(
        password: password,
        data: cleanedName.isEmpty ? null : _profileMetadata(cleanedName),
      ),
    );
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
