import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'services/app_settings.dart';

// IMPORT YOUR SCREENS
import 'package:ysma_museum_app/screens/splash_screen.dart';
import 'package:ysma_museum_app/screens/onboarding_screen.dart';
import 'package:ysma_museum_app/screens/home_screen.dart';
import 'package:ysma_museum_app/screens/recommended_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ INITIALIZE SUPABASE (VERY IMPORTANT)
  await Supabase.initialize(
    url: 'https://bepkeurohpfhacxxpqdb.supabase.co', // 🔁 REPLACE THIS
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJlcGtldXJvaHBmaGFjeHhwcWRiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2MTU4NjIsImV4cCI6MjA5MzE5MTg2Mn0.HXq7GzIfxSL7X7WD1KzrmI1nfXq1Dm84ShepR2Qv4PQ',            // 🔁 REPLACE THIS
  );

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YSMA Museum App',

      initialRoute: '/',

      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding1': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
        '/recommended': (context) => const RecommendedScreen(),
      },
    );
  }
}