import 'package:cuda_qurani/screens/main/stt/database/db_helper.dart';
import 'package:cuda_qurani/services/local_database_service.dart';
import 'package:cuda_qurani/services/mushaf_settings_service.dart';
import 'package:cuda_qurani/services/reciter_database_service.dart';
import 'package:cuda_qurani/services/widget_service.dart';
import 'package:cuda_qurani/services/daily_ayah_service.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:home_widget/home_widget.dart'; // ✅ NEW
import 'package:cuda_qurani/screens/main/stt/stt_page.dart'; // ✅ NEW
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/recitation_provider.dart';
import 'screens/main/home/services/juz_service.dart';
import 'package:cuda_qurani/screens/auth_wrapper.dart';
import 'package:cuda_qurani/providers/auth_provider.dart';
import 'package:cuda_qurani/screens/main/stt/services/quran_service.dart'; // ✅ TARTEEL: For preload
// import 'package:cuda_qurani/screens/main/stt/services/mushaf_preloader.dart'; // ✅ Background page preloader - DISABLED
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cuda_qurani/config/app_config.dart';
import 'package:cuda_qurani/screens/splash_screen.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';
import 'package:cuda_qurani/core/providers/language_provider.dart';
import 'package:cuda_qurani/providers/premium_provider.dart';
import 'package:cuda_qurani/providers/theme_provider.dart';
import 'package:cuda_qurani/providers/reminder_provider.dart';
import 'services/quran_resource_service.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

// Global flags to track initialization
bool _isDatabaseInitialized = false;
bool _isAppFullyInitialized = false;

/// Check if app is fully initialized for heavy operations
bool get isAppReady => _isAppFullyInitialized;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Workmanager: Executing task $task');
    try {
      // Initialize critical services for background task
      await LocalDatabaseService.preInitialize();
      await DailyAyahService.refreshDailyAyah();
      return Future.value(true);
    } catch (e) {
      print('Workmanager: Task failed: $e');
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

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

    // ✅ Start Mushaf preloader (render all 604 pages in background) - DISABLED
    // Future.delayed(const Duration(seconds: 2), () {
    //   print('[STARTUP] 📚 Starting Mushaf preloader...');
    //   MushafPreloader().startPreloading(prioritizeCommon: true);
    // });

    // Initialize Workmanager in background
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    ).then((_) {
      // Register periodic task for widget update (every 6 hours)
      Workmanager().registerPeriodicTask(
        'update-widget-task',
        'update-widget-task',
        frequency: const Duration(hours: 6),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    });

    // Initial trigger for widget (don't block UI)
    DailyAyahService.refreshDailyAyah();

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
        ChangeNotifierProvider(create: (_) => ReminderProvider()..initialize(), lazy: false),
        ChangeNotifierProvider(create: (_) => RecitationProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => QuranResourceService(), lazy: false),
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
    final startTime = DateTime.now();

    // ✅ 1. CHECK FOR DEEP LINK IMMEDIATELY
    int? targetPage;
    int? deepLinkAyahNum;
    bool isDeepLinkLaunch = false;

    try {
      final Uri? widgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (widgetUri != null && widgetUri.scheme == 'qurani' && widgetUri.host == 'ayah') {
        final segments = widgetUri.pathSegments;
        if (segments.length >= 2) {
          final surahId = int.tryParse(segments[0]);
          final ayahNum = int.tryParse(segments[1]);

          if (surahId != null && ayahNum != null) {
            isDeepLinkLaunch = true;
            deepLinkAyahNum = ayahNum;
            print('🔗 Early Deep Link Detect: Surah $surahId:$ayahNum');

            // We need DB to get page number, but we can wait for it while doing other things
          }
        }
      }
    } catch (e) {
      print('⚠️ Early Deep Link Error: $e');
    }

    // ✅ 2. Wait for AuthProvider to finish initialization
    int attempts = 0;
    const maxAttempts = 50;

    while (attempts < maxAttempts) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isLoading) break;
      } catch (e) {}
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    // ✅ 3. If Deep Link, wait for DB now (needed for targetPage)
    if (isDeepLinkLaunch) {
      int dbAttempts = 0;
      // Use polling to check for database readiness
      while (!_isDatabaseInitialized && dbAttempts < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        dbAttempts++;
      }

      // Resolve page number now that DB is ready
      try {
        if (_isDatabaseInitialized && deepLinkAyahNum != null) {
           // We need to retrieve the URI again to be sure, or store surahId
           // Better to store surahId from the first check
           final widgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
           if (widgetUri != null) {
              final surahId = int.tryParse(widgetUri.pathSegments[0]);
              if (surahId != null) {
                 targetPage = await LocalDatabaseService.getPageNumber(surahId, deepLinkAyahNum!);
              }
           }
        }
      } catch (e) {
         print('Deep Link Page Calc Error: $e');
      }
    }

    // ✅ 4. Duration logic
    // If deep link, minimal delay only if not ready.
    if (!isDeepLinkLaunch) {
       final elapsed = DateTime.now().difference(startTime);
       const minSplashDuration = Duration(milliseconds: 2000);
       if (elapsed < minSplashDuration) {
         await Future.delayed(minSplashDuration - elapsed);
       }
    }

    _startTarteelStylePreload();

    if (!mounted) return;

    // ✅ 5. Navigation
    print('🚀 Navigating... DeepLink=$isDeepLinkLaunch Page=$targetPage');

    // Pass deep link params directly to AuthWrapper for INSTANT render
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AuthWrapper(
          initialPageId: targetPage,
          highlightAyahId: deepLinkAyahNum,
        ),
        transitionDuration: isDeepLinkLaunch ? Duration.zero : const Duration(milliseconds: 300), // Zero delay for deep link
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (isDeepLinkLaunch) return child; // No animation for deep link
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    // ✅ 6. Final Deep Link Jump (Legacy/Backup removed as AuthWrapper handles it now)
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
