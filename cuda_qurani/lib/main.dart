import 'package:cuda_qurani/screens/main/stt/database/db_helper.dart';
import 'package:cuda_qurani/services/local_database_service.dart';
import 'package:cuda_qurani/services/mushaf_settings_service.dart';
import 'package:cuda_qurani/services/reciter_database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/recitation_provider.dart';
import 'screens/main/home/services/juz_service.dart';
import 'package:cuda_qurani/screens/auth_wrapper.dart';
import 'package:cuda_qurani/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cuda_qurani/config/app_config.dart';
import 'package:cuda_qurani/screens/splash_screen.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:cuda_qurani/core/providers/language_provider.dart';
import 'package:cuda_qurani/providers/premium_provider.dart';

// Global flag to track DB initialization
bool _isDatabaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  await MushafSettingsService().initialize();
  await _initializeDatabases();
  await JuzService.initialize();
  await _initializeListeningServices();
  await _initializeLanguageService();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // portrait normal
    // DeviceOrientation.portraitDown, // kalau mau ijinkan portrait terbalik
  ]);

  runApp(const MainApp());
}

Future<void> _initializeLanguageService() async {
  try {
    final languageProvider = LanguageProvider();
    await languageProvider.initialize();
  } catch (e, stackTrace) {
    // Don't throw - app should still work with default language
  }
}

Future<void> _initializeListeningServices() async {
  try {
    await ReciterDatabaseService.initialize();
  } catch (e) {}
}

Future<void> _initializeDatabases() async {
  if (_isDatabaseInitialized) {
    return;
  }

  try {
    await Future.wait([
      DBHelper.preInitializeAll(),
      LocalDatabaseService.preInitialize(),
    ]);
    await MetadataCacheService().initialize();

    _isDatabaseInitialized = true;
  } catch (e, stackTrace) {}
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(), lazy: false),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..initialize(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => PremiumProvider()..initialize(),
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => RecitationProvider(), lazy: true),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          final isRTL = languageProvider.currentLanguageCode == 'ar';

          return MaterialApp(
            title: 'Qurani Hafidz',
            debugShowCheckedModeBanner: false,

            locale: Locale(languageProvider.currentLanguageCode),

            supportedLocales: const [
              Locale('en'), // English
              Locale('id'), // Indonesian
              Locale('ar'), // Arabic - RTL
            ],

            // ✅ Tambahkan localization delegates
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            localeResolutionCallback: (locale, supportedLocales) {
              if (locale != null) {
                for (var supportedLocale in supportedLocales) {
                  if (supportedLocale.languageCode == locale.languageCode) {
                    return supportedLocale;
                  }
                }
              }
              return supportedLocales.first;
            },

            builder: (context, child) {
              return Directionality(
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                child: child!,
              );
            },

            theme: ThemeData(
              primarySwatch: Colors.green,
              primaryColor: const Color(0xFF247C64),
              scaffoldBackgroundColor: const Color(0xFFFFFFFF),
            ),
            home: const InitialSplashScreen(),
          );
        },
      ),
    );
  }
}

class InitialSplashScreen extends StatefulWidget {
  const InitialSplashScreen({super.key});

  @override
  State<InitialSplashScreen> createState() => _InitialSplashScreenState();
}

class _InitialSplashScreenState extends State<InitialSplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToAuth();
  }

  Future<void> _navigateToAuth() async {
    // Show splash for minimum 2 seconds (for branding)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Navigate to AuthWrapper (no animation for smooth transition)
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthWrapper(),
        transitionDuration: Duration.zero, // No animation
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen(); // Reuse existing SplashScreen widget
  }
}

// ============================================================================
// ✅ ARABIC NUMERALS HELPER - Tambahkan di bawah semua class
// ============================================================================

/// Utility class untuk convert angka Western (0-9) ke Eastern Arabic Numerals (٠-٩)
class AppLocalizations {
  /// Format number berdasarkan bahasa saat ini
  /// Jika bahasa Arab, convert ke Eastern Arabic Numerals
  static String formatNumber(BuildContext context, dynamic number) {
    try {
      final languageProvider = Provider.of<LanguageProvider>(
        context,
        listen: false,
      );

      if (languageProvider.currentLanguageCode == 'ar') {
        return _toArabicNumerals(number.toString());
      }
      return number.toString();
    } catch (e) {
      // Fallback jika error
      return number.toString();
    }
  }

  /// Convert Western digits (0-9) to Eastern Arabic Numerals (٠-٩)
  static String _toArabicNumerals(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    String result = input;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], arabic[i]);
    }
    return result;
  }
}

/// Extension untuk akses lebih mudah dari BuildContext
extension NumberFormattingExtension on BuildContext {
  /// Format number ke bahasa saat ini (Arab = ٠-٩, lainnya = 0-9)
  String formatNumber(dynamic number) {
    return AppLocalizations.formatNumber(this, number);
  }
}
