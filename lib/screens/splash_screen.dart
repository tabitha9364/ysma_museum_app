import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/user_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  late final StreamSubscription<AuthState> _authSubscription;
  bool _allowGoogleCallbackNavigation = false;
  bool _navigating = false;

  void _goToAuth() {
    if (_navigating || !mounted) {
      return;
    }

    _navigating = true;

    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }

  Future<void> _goToSignedInDestination(Session session) async {
    if (_navigating || !mounted) {
      return;
    }

    _navigating = true;
    await UserPreferences.setGoogleSignInPending(false);

    final email = session.user.email;
    if (email != null && email.trim().isNotEmpty) {
      await UserPreferences.saveEmail(email);
    }

    await UserPreferences.cacheProfileFromUser(session.user);
    final onboardingComplete = await UserPreferences.isOnboardingComplete();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      onboardingComplete ? '/home' : '/onboarding1',
      (route) => false,
    );
  }

  Future<void> _routeAfterSplash() async {
    final pendingGoogleSignIn =
        _allowGoogleCallbackNavigation ||
        await UserPreferences.isGoogleSignInPending();

    if (pendingGoogleSignIn) {
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        await _goToSignedInDestination(session);
        return;
      }
    }

    _goToAuth();
  }

  Future<void> _restoreGoogleCallbackIfNeeded() async {
    final pendingGoogleSignIn = await UserPreferences.isGoogleSignInPending();

    if (!mounted || !pendingGoogleSignIn) {
      return;
    }

    _allowGoogleCallbackNavigation = true;

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      await _goToSignedInDestination(session);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_restoreGoogleCallbackIfNeeded());

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) {
      final session = event.session;

      if (_allowGoogleCallbackNavigation && session != null) {
        unawaited(_goToSignedInDestination(session));
      }
    });

    _timer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;

      unawaited(_routeAfterSplash());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071A2F),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/images/stars.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2A44),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Image.asset(
                          'assets/images/museum_logo.png',
                          width: 50,
                        ),
                      ),

                      const SizedBox(width: 12),

                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YSMA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Text(
                            'SMART EXPERIENCE',
                            style: TextStyle(color: Colors.amber, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    'Enhancing Museum Experience Through AR',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
