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
import 'package:cuda_qurani/screens/main/stt/services/quran_service.dart'; // ✅ TARTEEL: For preload
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cuda_qurani/config/app_config.dart';
import 'package:cuda_qurani/screens/splash_screen.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:cuda_qurani/core/providers/language_provider.dart';
import 'package:cuda_qurani/providers/premium_provider.dart';
import 'package:cuda_qurani/providers/theme_provider.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

// Global flags to track initialization
bool _isDatabaseInitialized = false;
bool _isAppFullyInitialized = false;

/// Check if app is fully initialized for heavy operations
bool get isAppReady => _isAppFullyInitialized;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ OPTIMIZATION: Only initialize critical services synchronously
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // portrait normal
    // DeviceOrientation.portraitDown, // kalau mau ijinkan portrait terbalik
  ]);

  // ✅ Start app immediately, initialize heavy services in background
  runApp(const MainApp());

  // ✅ Initialize heavy services asynchronously after app starts
  _initializeServicesInBackground();
}

/// Initialize heavy services in background to prevent blocking UI
Future<void> _initializeServicesInBackground() async {
  try {
    print('[STARTUP] 🚀 Starting background initialization...');

    // Initialize in parallel for better performance
    await Future.wait([
      MushafSettingsService().initialize(),
      _initializeLanguageService(),
      _initializeListeningServices(),
    ]);

    // Initialize databases (heaviest operation)
    await _initializeDatabases();
    await JuzService.initialize();

    _isAppFullyInitialized = true;
    print('[STARTUP] ✅ Background initialization complete');
  } catch (e) {
    print('[STARTUP] ❌ Background initialization failed: $e');
    // Don't crash the app, just log the error
    _isAppFullyInitialized = true; // Set to true to prevent infinite loading
  }
}

Future<void> _initializeLanguageService() async {
  try {
    final languageProvider = LanguageProvider();
    await languageProvider.initialize();
  } catch (e) {
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
    print('[DB] 🔄 Starting database initialization...');
    final startTime = DateTime.now();

    // ✅ Initialize databases in parallel
    await Future.wait([
      DBHelper.preInitializeAll(),
      LocalDatabaseService.preInitialize(),
    ]);

    // ✅ Initialize metadata cache (this is the heavy operation)
    await MetadataCacheService().initialize();

    _isDatabaseInitialized = true;

    final duration = DateTime.now().difference(startTime);
    print(
      '[DB] ✅ Database initialization complete in ${duration.inMilliseconds}ms',
    );
  } catch (e) {
    print('[DB] ❌ Database initialization failed: $e');
    // Don't crash the app, set flag to prevent retries
    _isDatabaseInitialized = true;
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // ✅ AuthProvider must be initialized first and not lazy
        ChangeNotifierProvider(create: (_) => AuthProvider(), lazy: false),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..initialize(),
          lazy: false,
        ),
        // ✅ PremiumProvider depends on AuthProvider, so initialize after
        ChangeNotifierProvider(
          create: (_) => PremiumProvider()..initialize(),
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => RecitationProvider(), lazy: true),
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, child) {
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

            theme: AppTheme.lightTheme(context),
            darkTheme: AppTheme.darkTheme(context),
            themeMode: themeProvider.themeMode,
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
    // ✅ Wait for splash animation to complete (2 seconds) AND AuthProvider ready
    final startTime = DateTime.now();
    const minSplashDuration = Duration(
      milliseconds: 2000,
    ); // Match original splash timing

    // Wait for AuthProvider to finish initialization
    int attempts = 0;
    const maxAttempts = 50; // 5 seconds max (50 * 100ms)

    while (attempts < maxAttempts) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isLoading) {
          print('✅ AuthProvider ready');
          break;
        }
      } catch (e) {
        // Provider not ready yet
      }

      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    // ✅ Ensure minimum splash duration for animation to complete
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < minSplashDuration) {
      final remaining = minSplashDuration - elapsed;
      print(
        '⏱️ Waiting ${remaining.inMilliseconds}ms more for splash animation...',
      );
      await Future.delayed(remaining);
    }

    // ✅ TARTEEL-STYLE: Start preloading ALL pages in background
    // This runs in parallel with navigation, user won't wait
    _startTarteelStylePreload();

    if (!mounted) return;

    print('🚀 Navigating to AuthWrapper...');
    // Navigate to AuthWrapper
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthWrapper(),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// ✅ TARTEEL-STYLE: Preload all 604 pages in background
  void _startTarteelStylePreload() {
    // Import QuranService and start preload
    // This is fire-and-forget, runs in background
    Future.microtask(() async {
      try {
        // Dynamic import to avoid circular dependency
        final quranService = await _getQuranService();
        if (quranService != null) {
          quranService.preloadAllPagesInBackground();
        }
      } catch (e) {
        print('[InitialSplash] ⚠️ Background preload failed: $e');
      }
    });
  }

  /// Helper to get QuranService dynamically
  Future<QuranService?> _getQuranService() async {
    try {
      // Wait for databases to be ready
      if (!_isDatabaseInitialized) {
        print('[InitialSplash] ⏳ Waiting for database init before preload...');
        int waitCount = 0;
        while (!_isDatabaseInitialized && waitCount < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitCount++;
        }
      }

      // Get QuranService singleton instance
      final service = QuranService();
      await service.initialize();
      return service;
    } catch (e) {
      print('[InitialSplash] ⚠️ Failed to get QuranService: $e');
      return null;
    }
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

/// Extension untuk check app initialization status
extension AppStatusExtension on BuildContext {
  /// Check if app is fully initialized for heavy operations
  bool get isAppReady => _isAppFullyInitialized;

  /// Check if databases are initialized
  bool get isDatabaseReady => _isDatabaseInitialized;
}
