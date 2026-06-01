import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ysma_museum_app/screens/auth_screen.dart';
import 'package:ysma_museum_app/screens/home_screen.dart';
import 'package:ysma_museum_app/screens/museum_map_screen.dart';
import 'package:ysma_museum_app/screens/onboarding_screen.dart';
import 'package:ysma_museum_app/screens/recommended_screen.dart';
import 'package:ysma_museum_app/screens/splash_screen.dart';
import 'package:ysma_museum_app/services/app_settings.dart';
import 'package:ysma_museum_app/services/artwork_detection_service.dart';
import 'package:ysma_museum_app/services/user_preferences.dart';
import 'package:ysma_museum_app/services/voice_navigation_service.dart';
import 'package:ysma_museum_app/utils/colors.dart';

final ArtworkDetectionService artworkService = ArtworkDetectionService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bepkeurohpfhacxxpqdb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJlcGtldXJvaHBmaGFjeHhwcWRiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2MTU4NjIsImV4cCI6MjA5MzE5MTg2Mn0.HXq7GzIfxSL7X7WD1KzrmI1nfXq1Dm84ShepR2Qv4PQ',
  );

  await UserPreferences.primeCurrentUserProfile();
  await artworkService.loadModel();
  unawaited(VoiceNavigationService.warmUp());

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppSettings(),
      child: const YSMAApp(),
    ),
  );
}

class YSMAApp extends StatelessWidget {
  const YSMAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'YSMA Museum App',
          themeMode: settings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: AppColors.lightBackground,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: AppColors.background,
          ),
          home: const SplashScreen(),
          routes: {
            '/auth': (context) => const AuthScreen(),
            '/onboarding1': (context) => const OnboardingScreen(),
            '/home': (context) => const HomeScreen(),
            '/map': (context) => const MuseumMapScreen(),
            '/recommended': (context) => const RecommendedScreen(),
          },
        );
      },
    );
  }
}
