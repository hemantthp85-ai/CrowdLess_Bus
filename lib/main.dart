import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';


void main() async {
  // Ensure widget binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set default system overlay theme styles (status bar transparent)
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Firebase (safely catch configuration errors if credentials aren't placed yet)
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
    debugPrint('Please ensure google-services.json / GoogleService-Info.plist is configured.');
  }

  runApp(
    const ProviderScope(
      child: CrowdLessBusApp(),
    ),
  );
}

class CrowdLessBusApp extends StatelessWidget {
  const CrowdLessBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrowdLess Bus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Responsive support for system dark/light switching
      home: const SplashScreen(),
    );
  }
}
