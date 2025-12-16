// lib/screens/main/home/screens/all_session_page.dart

import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/main.dart';
import 'package:flutter/material.dart';
import 'package:cuda_qurani/screens/main/home/widgets/navigation_bar.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/widgets/app_components.dart';
import 'package:cuda_qurani/services/supabase_service.dart';
import 'package:cuda_qurani/services/auth_service.dart';
import 'package:cuda_qurani/screens/main/stt/stt_page.dart';

class AllSessionPage extends StatefulWidget {
  const AllSessionPage({Key? key}) : super(key: key);

  @override
  State<AllSessionPage> createState() => _AllSessionPageState();
}

class _AllSessionPageState extends State<AllSessionPage> {
  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('home/home');
    setState(() {
      _translations = trans;
    });
  }

  // ==================== DATA STRUCTURE ====================
  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService(); // ✅ Add AuthService
  List<SessionData> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _loadTranslations();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);

    try {
      // ✅ Get current user UUID
      final userUuid = _authService.userId;

      print('📱 ALL_SESSION: Starting load...');
      print('👤 ALL_SESSION: User UUID: $userUuid');

      if (userUuid == null) {
        print('⚠️ ALL_SESSION: User not authenticated');
        setState(() {
          _isLoading = false;
          _sessions = [];
        });
        return;
      }

      // ✅ Fetch sessions filtered by user (includes ALL statuses: active, paused, stopped)
      print('📡 ALL_SESSION: Fetching sessions from database...');
      final sessions = await _supabaseService.getAllSessions(
        userUuid: userUuid,
      );

      print('✅ ALL_SESSION: Loaded ${sessions.length} sessions');
      if (sessions.isNotEmpty) {
        print(
          '📋 ALL_SESSION: First session - ID: ${sessions[0]['session_id']}, Status: ${sessions[0]['status']}',
        );
      }

      setState(() {
        _sessions = sessions.map((s) => SessionData.fromSupabase(s)).toList();
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ ALL_SESSION: Error loading sessions: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
        _sessions = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundLight(context),
      appBar: ProfileAppBar(
        title: _translations.isNotEmpty
            ? LanguageHelper.tr(_translations, 'home.session.session_text')
            : 'Session',
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context),
      ),
    );
  }

  // ==================== BODY ====================
  Widget _buildBody(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header Section
        SliverToBoxAdapter(
          child: Padding(
            padding: AppPadding.only(
              context,
              left: AppDesignSystem.space20,
              right: AppDesignSystem.space20,
              top: AppDesignSystem.space12,
              bottom: AppDesignSystem.space8,
            ),
            child: _buildHeader(context),
          ),
        ),

        // Sessions List
        SliverPadding(
          padding: AppPadding.horizontal(context, AppDesignSystem.space20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return Padding(
                padding: AppPadding.only(
                  context,
                  bottom: AppDesignSystem.space8,
                ),
                child: _buildSessionCard(context, _sessions[index]),
              );
            }, childCount: _sessions.length),
          ),
        ),

        // Bottom Spacing
        SliverToBoxAdapter(child: SizedBox(height: AppDesignSystem.space16)),
      ],
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader(BuildContext context) {
    final String headerText = _translations.isNotEmpty
        ? LanguageHelper.tr(
            _translations,
            'home.session.sessions_text',
          ).toUpperCase()
        : 'SESSIONS';
    return Text(
      '${context.formatNumber(_sessions.length)} $headerText',
      style: AppTypography.overline(context, color: AppColors.textTertiary),
    );
  }

  // ==================== SESSION CARD ====================
  Widget _buildSessionCard(BuildContext context, SessionData session) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.medium();
          _navigateToSession(context, session);
        },
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
        splashColor: AppComponentStyles.rippleColor,
        highlightColor: AppComponentStyles.hoverColor,
        child: Container(
          padding: EdgeInsets.all(
            AppDesignSystem.space12 * AppDesignSystem.getScaleFactor(context),
          ),
          decoration: AppComponentStyles.card(
            borderColor: AppColors.borderLight,
            shadow: false,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session Type Label (smaller)
              Text(
                _getSessionTypeLabel(session.type).toUpperCase(),
                style: AppTypography.captionSmall(
                  context,
                  color: AppColors.textDisabled,
                  weight: AppTypography.semiBold,
                ),
              ),

              SizedBox(
                height:
                    AppDesignSystem.space8 *
                    AppDesignSystem.getScaleFactor(context),
              ),

              // Main Content Row
              Row(
                children: [
                  // Icon Container (smaller)
                  Container(
                    width: 36 * AppDesignSystem.getScaleFactor(context),
                    height: 36 * AppDesignSystem.getScaleFactor(context),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusSmall,
                      ),
                    ),
                    child: Icon(
                      _getSessionIcon(session.type),
                      size: AppDesignSystem.iconMedium,
                      color: AppColors.primary,
                    ),
                  ),

                  SizedBox(
                    width:
                        AppDesignSystem.space10 *
                        AppDesignSystem.getScaleFactor(context),
                  ),

                  // Surah Info
                  Expanded(child: _buildSurahInfo(context, session)),
                ],
              ),

              SizedBox(
                height:
                    AppDesignSystem.space8 *
                    AppDesignSystem.getScaleFactor(context),
              ),

              // Bottom Row - Timestamp & Action (no divider)
              _buildBottomRow(context, session),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== TYPE BADGE ====================
  // REMOVED - Using simple text label instead

  // ==================== SURAH INFO ====================
  Widget _buildSurahInfo(BuildContext context, SessionData session) {
    final String versesText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, 'home.ayah_text').toLowerCase()
        : 'Verses';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Surah Name (smaller)
        Text(
          session.surah,
          style: AppTypography.title(context, weight: AppTypography.semiBold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        SizedBox(
          height:
              AppDesignSystem.space4 * AppDesignSystem.getScaleFactor(context),
        ),

        // Duration & Verses (compact)
        Row(
          children: [
            Text(
              _formatDurationWithContext(context, session.duration),
              style: AppTypography.captionSmall(context),
            ),

            // Separator Dot
            Container(
              margin: EdgeInsets.symmetric(
                horizontal:
                    AppDesignSystem.space6 *
                    AppDesignSystem.getScaleFactor(context),
              ),
              width: AppDesignSystem.space2,
              height: AppDesignSystem.space2,
              decoration: const BoxDecoration(
                color: AppColors.borderDark,
                shape: BoxShape.circle,
              ),
            ),

            Text(
              '${context.formatNumber(session.verses)} $versesText',
              style: AppTypography.captionSmall(context),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== BOTTOM ROW ====================
  Widget _buildBottomRow(BuildContext context, SessionData session) {
    return Row(
      children: [
        // Timestamp (compact, no icon)
        Expanded(
          child: Text(
            '${_formatDisplayDate(context, session.displayDate)} ${_formatDisplayTime(context, session.displayTime)}',
            style: AppTypography.captionSmall(
              context,
              color: AppColors.textDisabled,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        SizedBox(
          width:
              AppDesignSystem.space8 * AppDesignSystem.getScaleFactor(context),
        ),

        // Continue Button
        _buildContinueButton(context),
      ],
    );
  }

  // ==================== CONTINUE BUTTON ====================
  Widget _buildContinueButton(BuildContext context) {
    final String continueText = _translations.isNotEmpty
        ? LanguageHelper.tr(_translations, 'home.session.continue_text')
        : 'Continue';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.light();
          // TODO: Navigate to reading page
        },
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
        splashColor: AppComponentStyles.rippleColor,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal:
                AppDesignSystem.space6 *
                AppDesignSystem.getScaleFactor(context),
            vertical:
                AppDesignSystem.space4 *
                AppDesignSystem.getScaleFactor(context),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                continueText,
                style: AppTypography.captionSmall(
                  context,
                  color: AppColors.primary,
                  weight: AppTypography.semiBold,
                ),
              ),
              SizedBox(
                width:
                    AppDesignSystem.space2 *
                    AppDesignSystem.getScaleFactor(context),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: AppDesignSystem.iconXSmall,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HELPER METHODS ====================

  String _formatDisplayDate(BuildContext context, String displayDate) {
    // Format: "TODAY" or "JANUARY 15, 2024"
    if (displayDate == 'TODAY') {
      return displayDate;
    }
    // Extract and format numbers in date
    final parts = displayDate.split(' ');
    if (parts.length >= 3) {
      final month = parts[0]; // JANUARY
      final day = parts[1].replaceAll(',', ''); // 15
      final year = parts[2]; // 2024
      return '$month ${context.formatNumber(int.parse(day))}, ${context.formatNumber(int.parse(year))}';
    }
    return displayDate;
  }

  String _formatDisplayTime(BuildContext context, String displayTime) {
    // Format: "3:45PM" -> format the numbers
    final match = RegExp(r'(\d+):(\d+)([AP]M)').firstMatch(displayTime);
    if (match != null) {
      final hour = match.group(1)!;
      final minute = match.group(2)!;
      final period = match.group(3)!;
      return '${context.formatNumber(int.parse(hour))}:${context.formatNumber(int.parse(minute))}$period';
    }
    return displayTime;
  }

  String _getSessionTypeLabel(SessionType type) {
    if (_translations.isEmpty) {
      return type.displayName;
    }
    switch (type) {
      case SessionType.reading:
        return LanguageHelper.tr(_translations, 'home.session.reading_text');
      case SessionType.memorization:
        return 'Memorization'; // Add to JSON if needed
      case SessionType.revision:
        return 'Revision'; // Add to JSON if needed
    }
  }

  IconData _getSessionIcon(SessionType type) {
    switch (type) {
      case SessionType.reading:
        return Icons.menu_book_rounded;
      case SessionType.memorization:
        return Icons.psychology_rounded;
      case SessionType.revision:
        return Icons.refresh_rounded;
    }
  }

  Color _getTypeColor(SessionType type) {
    switch (type) {
      case SessionType.reading:
        return AppColors.primary;
      case SessionType.memorization:
        return AppColors.secondary;
      case SessionType.revision:
        return AppColors.accent;
    }
  }

  String _formatDuration(Duration duration) {
    final String minText = _translations.isNotEmpty
        ? LanguageHelper.tr(
            _translations,
            'home.session.min_text',
          ).toLowerCase()
        : 'min';
    if (duration.inMinutes == 0) {
      return '< 1 $minText';
    }
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '$minutes $minText';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours hr';
    }
    return '$hours hr $remainingMinutes $minText';
  }

  String _formatDurationWithContext(BuildContext context, Duration duration) {
    final String minText = _translations.isNotEmpty
        ? LanguageHelper.tr(
            _translations,
            'home.session.min_text',
          ).toLowerCase()
        : 'min';
    if (duration.inMinutes == 0) {
      return '< ${context.formatNumber(1)} $minText';
    }
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '${context.formatNumber(minutes)} $minText';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '${context.formatNumber(hours)} hr';
    }
    return '${context.formatNumber(hours)} hr ${context.formatNumber(remainingMinutes)} $minText';
  }

  void _navigateToSession(BuildContext context, SessionData session) {
    if (session.surahId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppComponentStyles.errorSnackBar(message: 'Invalid session data'),
      );
      return;
    }

    print('📱 ALL_SESSION: Navigating to SttPage');
    print('   surahId: ${session.surahId}');
    print('   isFromHistory: true');
    print('   status: ${session.status}');
    print('   sessionId: ${session.sessionId}');
    print('   wordStatusMap: ${session.wordStatusMap?.keys.length ?? 0} ayahs');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SttPage(
          suratId: session.surahId!,
          isFromHistory: true,
          initialWordStatusMap: session.wordStatusMap,
          resumeSessionId: session.sessionId, // ✅ NEW: Pass session_id
        ),
      ),
    );
  }
}

// ==================== SESSION DATA MODEL ====================
enum SessionType {
  reading,
  memorization,
  revision;

  String get displayName {
    switch (this) {
      case SessionType.reading:
        return 'Reading';
      case SessionType.memorization:
        return 'Memorization';
      case SessionType.revision:
        return 'Revision';
    }
  }
}

class SessionData {
  final SessionType type;
  final String surah;
  final Duration duration;
  final int verses;
  final DateTime timestamp;
  final String displayDate;
  final String displayTime;
  final String? sessionId;
  final int? surahId;
  final String? status;
  final int? position;
  final Map<String, dynamic>? wordStatusMap; // ✅ NEW

  SessionData({
    required this.type,
    required this.surah,
    required this.duration,
    required this.verses,
    required this.timestamp,
    required this.displayDate,
    required this.displayTime,
    this.sessionId,
    this.surahId,
    this.status,
    this.position,
    this.wordStatusMap, // ✅ NEW
  });

  factory SessionData.fromSupabase(Map<String, dynamic> data) {
    final timestamp = DateTime.parse(
      data['created_at'] ?? DateTime.now().toIso8601String(),
    );
    final surahId = data['surah_id'] as int? ?? 1;
    final ayah = data['ayah'] as int? ?? 1;
    final position = data['position'] as int? ?? 0;
    final status = data['status'] as String? ?? 'unknown';

    // ✅ NEW: Extract word_status_map from data
    Map<String, dynamic>? wordStatusMap;
    if (data['data'] != null && data['data']['word_status_map'] != null) {
      wordStatusMap = Map<String, dynamic>.from(
        data['data']['word_status_map'],
      );
    }

    final surahName = _getSurahName(surahId);

    return SessionData(
      type: SessionType.reading,
      surah: '$surahName - Ayah $ayah',
      duration: Duration(minutes: 0),
      verses: ayah,
      timestamp: timestamp,
      displayDate: _formatDate(timestamp),
      displayTime: _formatTime(timestamp),
      sessionId: data['session_id'],
      surahId: surahId,
      status: status,
      position: position,
      wordStatusMap: wordStatusMap, // ✅ NEW
    );
  }

  static String _getSurahName(int surahId) {
    const surahNames = {
      1: 'Al-Fatihah',
      2: 'Al-Baqarah',
      3: "Ali 'Imran",
      4: 'An-Nisa',
      5: 'Al-Maidah',
      6: "Al-An'am",
      7: "Al-A'raf",
      8: 'Al-Anfal',
      9: 'At-Tawbah',
      10: 'Yunus',
      11: 'Hud',
      12: 'Yusuf',
      13: "Ar-Ra'd",
      14: 'Ibrahim',
      15: 'Al-Hijr',
      16: 'An-Nahl',
      17: 'Al-Isra',
      18: 'Al-Kahf',
      19: 'Maryam',
      20: 'Ta-Ha',
      21: 'Al-Anbiya',
      22: 'Al-Hajj',
      23: "Al-Mu'minun",
      24: 'An-Nur',
      25: 'Al-Furqan',
      26: "Ash-Shu'ara",
      27: 'An-Naml',
      28: 'Al-Qasas',
      29: "Al-'Ankabut",
      30: 'Ar-Rum',
      31: 'Luqman',
      32: 'As-Sajdah',
      33: 'Al-Ahzab',
      34: 'Saba',
      35: 'Fatir',
      36: 'Ya-Sin',
      37: 'As-Saffat',
      38: 'Sad',
      39: 'Az-Zumar',
      40: 'Ghafir',
      41: 'Fussilat',
      42: 'Ash-Shura',
      43: 'Az-Zukhruf',
      44: 'Ad-Dukhan',
      45: 'Al-Jathiyah',
      46: 'Al-Ahqaf',
      47: 'Muhammad',
      48: 'Al-Fath',
      49: 'Al-Hujurat',
      50: 'Qaf',
      51: 'Adh-Dhariyat',
      52: 'At-Tur',
      53: 'An-Najm',
      54: 'Al-Qamar',
      55: 'Ar-Rahman',
      56: "Al-Waqi'ah",
      57: 'Al-Hadid',
      58: 'Al-Mujadila',
      59: 'Al-Hashr',
      60: 'Al-Mumtahanah',
      61: 'As-Saff',
      62: "Al-Jumu'ah",
      63: 'Al-Munafiqun',
      64: 'At-Taghabun',
      65: 'At-Talaq',
      66: 'At-Tahrim',
      67: 'Al-Mulk',
      68: 'Al-Qalam',
      69: 'Al-Haqqah',
      70: "Al-Ma'arij",
      71: 'Nuh',
      72: 'Al-Jinn',
      73: 'Al-Muzzammil',
      74: 'Al-Muddaththir',
      75: 'Al-Qiyamah',
      76: 'Al-Insan',
      77: 'Al-Mursalat',
      78: 'An-Naba',
      79: "An-Nazi'at",
      80: "'Abasa",
      81: 'At-Takwir',
      82: 'Al-Infitar',
      83: 'Al-Mutaffifin',
      84: 'Al-Inshiqaq',
      85: 'Al-Buruj',
      86: 'At-Tariq',
      87: "Al-A'la",
      88: 'Al-Ghashiyah',
      89: 'Al-Fajr',
      90: 'Al-Balad',
      91: 'Ash-Shams',
      92: 'Al-Layl',
      93: 'Ad-Duha',
      94: 'Ash-Sharh',
      95: 'At-Tin',
      96: "Al-'Alaq",
      97: 'Al-Qadr',
      98: 'Al-Bayyinah',
      99: 'Az-Zalzalah',
      100: "Al-'Adiyat",
      101: "Al-Qari'ah",
      102: 'At-Takathur',
      103: "Al-'Asr",
      104: 'Al-Humazah',
      105: 'Al-Fil',
      106: 'Quraysh',
      107: "Al-Ma'un",
      108: 'Al-Kawthar',
      109: 'Al-Kafirun',
      110: 'An-Nasr',
      111: 'Al-Masad',
      112: 'Al-Ikhlas',
      113: 'Al-Falaq',
      114: 'An-Nas',
    };
    return surahNames[surahId] ?? 'Surah $surahId';
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'TODAY';
    }
    return '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')}$period';
  }

  static String _monthName(int month) {
    const months = [
      '',
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return months[month];
  }
}



