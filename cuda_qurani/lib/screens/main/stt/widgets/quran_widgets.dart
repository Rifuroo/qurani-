// lib\screens\main\stt\widgets\quran_widgets.dart
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/main.dart';
import 'package:cuda_qurani/models/playback_settings_model.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/settings_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/surah_list_page.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/playback_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/stt_controller.dart';
import '../utils/constants.dart';
import 'package:cuda_qurani/core/providers/language_provider.dart';
import 'package:cuda_qurani/services/metadata_cache_service.dart';

class QuranAppBar extends StatefulWidget implements PreferredSizeWidget {
  const QuranAppBar({Key? key}) : super(key: key);

  @override
  State<QuranAppBar> createState() => _QuranAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight * 0.86);
}

class _QuranAppBarState extends State<QuranAppBar> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('stt');
    setState(() {
      _translations = trans;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SttController>();
    final languageProvider = context.watch<LanguageProvider>();
    final isArabic = languageProvider.currentLanguageCode == 'ar';

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive sizing
    final iconSize = screenWidth * 0.060;
    final titleSize = screenWidth * 0.028;
    final subtitleSize = screenWidth * 0.028;
    final badgeSize = screenWidth * 0.028;

    // ✅ NEW: Determine display name with Arabic support
    String displaySurahName;
    if (controller.suratNameSimple.isNotEmpty) {
      if (isArabic) {
        // ✅ Use Arabic name if language is Arabic
        final metadataCache = MetadataCacheService();

        // Try to get Arabic name from cache or current page
        if (controller.currentPageAyats.isNotEmpty) {
          final surahId = controller.currentPageAyats.first.surah_id;
          displaySurahName = metadataCache.getPrimarySurahForPage(
            controller.currentPage,
            useArabic: true,
          );

          // Fallback if cache doesn't have it
          if (displaySurahName.isEmpty || displaySurahName == 'Unknown Surah') {
            displaySurahName = controller.suratNameSimple;
          }
        } else {
          displaySurahName = controller.suratNameSimple;
        }
      } else {
        // Use simple name for non-Arabic languages
        displaySurahName = controller.suratNameSimple;
      }
    } else if (controller.ayatList.isNotEmpty) {
      displaySurahName = 'Surah ${controller.ayatList.first.surah_id}';
    } else {
      displaySurahName = 'Loading...';
    }

    final int currentJuz = controller.currentPageAyats.isNotEmpty
        ? controller.calculateJuz(
            controller.currentPageAyats.first.surah_id,
            controller.currentPageAyats.first.ayah,
          )
        : 1;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: controller.isUIVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !controller.isUIVisible,
        child: AppBar(
          backgroundColor: AppColors.getSurfaceContainerHigh(context),
          foregroundColor: AppColors.getTextPrimary(context),
          toolbarHeight: kToolbarHeight * 0.80,
          leading: IconButton(
            icon: Icon(
              Icons.menu, 
              size: iconSize * 120 / 100,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/qurani-white-text.png',
                height: screenHeight * 0.016,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
              SizedBox(height: screenHeight * 0.006),
              // Info Row with structured layout
              Row(
                children: [
                  // Surah Name
                  Flexible(
                    child: Text(
                      displaySurahName,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w400,
                        color: AppColors.getTextPrimary(context).withOpacity(0.9),
                        height: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  // Separator
                  Container(
                    width: 1,
                    height: screenHeight * 0.016,
                    color: AppColors.getTextSecondary(context).withOpacity(0.3),
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  // Juz Badge
                  Text(
                    '${LanguageHelper.tr(_translations, "app_bar.juz_text")} ${context.formatNumber(currentJuz)}',
                    style: TextStyle(
                      fontSize: badgeSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.getTextPrimary(context).withOpacity(0.9),
                      height: 1.1,
                    ),
                  ),

                  SizedBox(width: screenWidth * 0.015),
                  // Separator
                  Container(
                    width: 1,
                    height: screenHeight * 0.016,
                    color: AppColors.getTextSecondary(context).withOpacity(0.3),
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  // Page Number
                  Text(
                    '${LanguageHelper.tr(_translations, "app_bar.page_text")} ${context.formatNumber(controller.currentPage)}',
                    style: TextStyle(
                      fontSize: subtitleSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.getTextPrimary(context).withOpacity(0.9),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          titleSpacing: 0,
          actions: [
            // Mode Toggle
            // Mode Toggle
            IconButton(
              icon: Icon(
                controller.isQuranMode
                    ? Icons.vertical_split
                    : Icons.auto_stories,
                size: iconSize * 0.9,
                color: AppColors.getTextPrimary(context),
              ),
              onPressed: () async {
                // ✅ FIX: Await toggle completion
                await controller.toggleQuranMode();

                // ✅ FORCE: Trigger rebuild immediately
                if (context.mounted) {
                  // Scroll to correct position after mode change
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // Trigger any pending navigation
                    controller.notifyListeners();
                  });
                }
              },
              splashRadius: iconSize * 1.1,
            ),
            // Visibility Toggle
            IconButton(
              icon: Icon(
                controller.hideUnreadAyat
                    ? Icons.visibility
                    : Icons.visibility_off,
                size: iconSize * 0.9,
                color: AppColors.getTextPrimary(context),
              ),
              onPressed: controller.toggleHideUnread,
              splashRadius: iconSize * 1.1,
            ),
            // More Options Menu
            IconButton(
              onPressed: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const SettingsPage(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        const begin = Offset(0.03, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        var tween = Tween(
                          begin: begin,
                          end: end,
                        ).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);
                        var fadeAnimation = animation.drive(
                          Tween(
                            begin: 0.0,
                            end: 1.0,
                          ).chain(CurveTween(curve: curve)),
                        );

                        return FadeTransition(
                          opacity: fadeAnimation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                  transitionDuration: AppDesignSystem.durationNormal,
                ),
              ), // dikosongin
              icon: Icon(
                Icons.settings, 
                size: iconSize * 0.9,
                color: AppColors.getTextPrimary(context),
              ),
              splashRadius: iconSize * 1.1,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight * 0.86);
}

class QuranBottomBar extends StatefulWidget {
  const QuranBottomBar({Key? key}) : super(key: key);

  @override
  State<QuranBottomBar> createState() => _QuranBottomBarState();
}

class _QuranBottomBarState extends State<QuranBottomBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  double _dragPosition = 0.0; // -1 (left/listen) to 1 (right/recite)
  String? _activeMode; // 'listen', 'recite', or null
  bool _isDragging = false;

  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('stt');
    setState(() {
      _translations = trans;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(double delta, double maxWidth) {
    setState(() {
      _isDragging = true;
      _dragPosition = (_dragPosition + delta / maxWidth).clamp(-1.0, 1.0);
    });
  }

  Future<void> _handleDragEnd(SttController controller) async {
    const threshold = 0.90; // 70% slide required to activate

    if (_dragPosition < -threshold) {
      // Activated LISTEN mode
      await _activateMode('listen', controller);
    } else if (_dragPosition > threshold) {
      // Activated RECITE mode
      await _activateMode('recite', controller);
    } else {
      // Return to center
      _resetToCenter();
    }

    setState(() {
      _isDragging = false;
    });
  }

  Future<void> _activateMode(String mode, SttController controller) async {
    AppHaptics.medium();

    setState(() {
      _activeMode = mode;
    });

    if (mode == 'listen') {
      // ✅ PENTING: Reset posisi button ke tengah SEBELUM membuka settings
      _resetToCenter(keepActiveMode: true);

      // Open playback settings
      final settings = await Navigator.push<PlaybackSettings>(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              PlaybackSettingsPage(currentPage: controller.currentPage),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.3);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            var fadeAnimation = animation.drive(
              Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve)),
            );
            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
          transitionDuration: AppDesignSystem.durationNormal,
        ),
      );

      if (settings != null) {
        try {
          await controller.startListening(settings);
          // ✅ Button tetap di tengah setelah listening dimulai
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$e'),
                backgroundColor: AppColors.getError(context),
                duration: const Duration(seconds: 5),
              ),
            );
          }
          // ✅ Jika gagal, reset button
          _resetToCenter(keepActiveMode: false);
        }
      } else {
        // ✅ User cancel settings, reset button
        _resetToCenter(keepActiveMode: false);
      }
    } else if (mode == 'recite') {
      await controller.startRecording();
      _resetToCenter(keepActiveMode: false); // Recite mode tetap reset penuh
    }
  }

  void _resetToCenter({bool keepActiveMode = false}) {
    _slideController.reverse(from: 1.0);
    setState(() {
      _dragPosition = 0.0;
      if (!keepActiveMode) {
        _activeMode = null;
      }
    });
  }

  Future<void> _handleCenterButtonTap(SttController controller) async {
    AppHaptics.light();

    if (controller.isListeningMode) {
      final audioService = controller.listeningAudioService;
      if (audioService != null) {
        if (audioService.isPaused) {
          await controller.resumeListening();
        } else {
          await controller.pauseListening();
        }
        // ✅ Widget akan auto-rebuild via context.watch<SttController>()
        // Tidak perlu setState karena controller sudah memanggil notifyListeners()
      }
    } else if (controller.isRecording) {
      await controller.stopRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SttController>();
    if (_activeMode == 'listen' && !controller.isListeningMode) {
      // Listening mode telah selesai, reset button
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resetToCenter(keepActiveMode: false);
        }
      });
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final containerHeight = screenHeight * 0.15;
    final trackWidth = screenWidth * 0.75;
    final trackHeight = screenHeight * 0.065;
    final thumbSize = trackHeight * 0.85;
    final iconSize = screenWidth * 0.065;
    final labelSize = screenWidth * 0.032;
    final bottomOffset = screenHeight * 0.057;

    final isListeningActive = controller.isListeningMode;
    final isRecordingActive = controller.isRecording;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: controller.isUIVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !controller.isUIVisible,
        child: SizedBox(
          height: containerHeight,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Main Slider Track
              Positioned(
                bottom: bottomOffset,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    _handleDragUpdate(details.delta.dx, trackWidth / 2);
                  },
                  onHorizontalDragEnd: (details) {
                    _handleDragEnd(controller);
                  },
                  child: Container(
                    width: trackWidth,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(context),
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.getShadowLight(context),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Left Label (Listen)
                        Positioned(
                          left: trackWidth * 0.08,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _dragPosition < -0.3 ? 1.0 : 0.4,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: iconSize * 0.9,
                                  color: isListeningActive
                                      ? getPrimaryColor(context)
                                      : Colors.white.withOpacity(0.9),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  _translations.isNotEmpty
                                      ? LanguageHelper.tr(
                                          _translations,
                                          'bottom_bar.listen_text',
                                        )
                                      : 'Listen',
                                  style: TextStyle(
                                    fontSize: labelSize,
                                    fontWeight: FontWeight.w600,
                                    color: isListeningActive
                                        ? getPrimaryColor(context)
                                        : Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Right Label (Recite)
                        Positioned(
                          right: trackWidth * 0.08,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _dragPosition > 0.3 ? 1.0 : 0.4,
                            child: Row(
                              children: [
                                Text(
                                  _translations.isNotEmpty
                                      ? LanguageHelper.tr(
                                          _translations,
                                          'bottom_bar.recite_text',
                                        )
                                      : 'Recite',
                                  style: TextStyle(
                                    fontSize: labelSize,
                                    fontWeight: FontWeight.w600,
                                    color: isRecordingActive
                                        ? getErrorColor(context)
                                        : Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.mic_rounded,
                                  size: iconSize * 0.9,
                                  color: isRecordingActive
                                      ? getErrorColor(context)
                                      : Colors.white.withOpacity(0.9),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Sliding Thumb Button
                        AnimatedPositioned(
                          duration: _isDragging
                              ? Duration.zero
                              : const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          left:
                              ((trackWidth / 2) - (thumbSize / 2)) +
                              (_dragPosition *
                                  (trackWidth / 2 - thumbSize / 2)),
                          child: GestureDetector(
                            onTap: () => _handleCenterButtonTap(controller),
                            child: Container(
                              width: thumbSize,
                              height: thumbSize,
                              decoration: BoxDecoration(
                                color: _getThumbColor(
                                  isListeningActive,
                                  isRecordingActive,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _getThumbColor(
                                      isListeningActive,
                                      isRecordingActive,
                                    ).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(
                                    milliseconds: 150,
                                  ), // ✅ Kurangi delay
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    );
                                  },
                                  child: Builder(
                                    builder: (context) {
                                      // ✅ CRITICAL: Baca state terbaru setiap rebuild
                                      final audioService =
                                          controller.listeningAudioService;
                                      final isPaused =
                                          audioService?.isPaused ?? false;
                                      final icon = _getThumbIcon(
                                        controller,
                                        isListeningActive,
                                        isRecordingActive,
                                      );

                                      // ✅ CRITICAL: Gunakan icon codePoint sebagai bagian dari key untuk memastikan AnimatedSwitcher detect perubahan
                                      return Icon(
                                        icon,
                                        key: ValueKey(
                                          'icon_${icon.codePoint}_${isListeningActive}_${isRecordingActive}_${isPaused}_${_dragPosition.toStringAsFixed(1)}',
                                        ), // ✅ Key yang unik termasuk icon codePoint untuk memastikan perubahan terdeteksi
                                        color: AppColors.getTextInverse(context),
                                        size: iconSize,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Active Mode Indicator (Small Settings Button for Listen Mode)
              if (isListeningActive && !_isDragging)
                Positioned(
                  bottom: bottomOffset + trackHeight + 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        AppHaptics.light();
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    PlaybackSettingsPage(
                                      currentPage: controller.currentPage,
                                    ),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  const begin = Offset(0.0, 0.3);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOut;
                                  var tween = Tween(
                                    begin: begin,
                                    end: end,
                                  ).chain(CurveTween(curve: curve));
                                  var offsetAnimation = animation.drive(tween);
                                  var fadeAnimation = animation.drive(
                                    Tween(
                                      begin: 0.0,
                                      end: 1.0,
                                    ).chain(CurveTween(curve: curve)),
                                  );
                                  return FadeTransition(
                                    opacity: fadeAnimation,
                                    child: SlideTransition(
                                      position: offsetAnimation,
                                      child: child,
                                    ),
                                  );
                                },
                            transitionDuration: AppDesignSystem.durationNormal,
                          ),
                        );
                      },
                      // child: Container(
                      //   padding: const EdgeInsets.symmetric(
                      //     horizontal: 12,
                      //     vertical: 6,
                      //   ),
                      //   decoration: BoxDecoration(
                      //     color: primaryColor.withOpacity(0.1),
                      //     borderRadius: BorderRadius.circular(20),
                      //     border: Border.all(
                      //       color: primaryColor.withOpacity(0.3),
                      //       width: 1,
                      //     ),
                      //   ),
                      //   child: Row(
                      //     mainAxisSize: MainAxisSize.min,
                      //     children: [
                      //       Icon(
                      //         Icons.tune,
                      //         size: iconSize * 0.7,
                      //         color: primaryColor,
                      //       ),
                      //       SizedBox(width: 4),
                      //       Text(
                      //         'Playback Settings',
                      //         style: TextStyle(
                      //           fontSize: labelSize * 0.85,
                      //           color: primaryColor,
                      //           fontWeight: FontWeight.w500,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getThumbColor(bool isListening, bool isRecording) {
    if (isListening) return getPrimaryColor(context);
    if (isRecording) return getErrorColor(context);

    // During drag, show preview color
    if (_isDragging) {
      if (_dragPosition < -0.3) return getPrimaryColor(context).withOpacity(0.7);
      if (_dragPosition > 0.3) return getErrorColor(context).withOpacity(0.7);
    }

    return AppColors.getTextTertiary(context);
  }

  IconData _getThumbIcon(
    SttController controller,
    bool isListening,
    bool isRecording,
  ) {
    if (isListening) {
      final audioService = controller.listeningAudioService;
      if (audioService != null && audioService.isPaused) {
        return Icons.play_arrow;
      }
      return Icons.pause;
    }

    if (isRecording) {
      return Icons.stop;
    }

    // Show preview icons during drag
    if (_isDragging) {
      if (_dragPosition < -0.5) return Icons.play_arrow;
      if (_dragPosition > 0.5) return Icons.mic;
    }

    return Icons.code;
  }


}

class QuranLoadingWidget extends StatelessWidget {
  final String errorMessage;
  const QuranLoadingWidget({Key? key, required this.errorMessage})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final containerSize = screenWidth * 0.15; // ✅ ~60px pada 400px width
    final titleSize = screenWidth * 0.04; // ✅ ~16px pada 400px width
    final messageSize = screenWidth * 0.03;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: getPrimaryColor(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.getTextInverse(context)),
                strokeWidth: 2,
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.015),
          Text(
            'Initializing App...',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
              color: getPrimaryColor(context),
            ),
          ),
          SizedBox(height: screenHeight * 0.005),
          Text(
            errorMessage.isNotEmpty ? errorMessage : 'Loading Quran data...',
            style: TextStyle(
              fontSize: messageSize,
              color: AppColors.getTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class QuranErrorWidget extends StatelessWidget {
  const QuranErrorWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final containerSize = screenWidth * 0.2;
    final iconSize = screenWidth * 0.1;
    final titleSize = screenWidth * 0.045;
    final messageSize = screenWidth * 0.03;
    final buttonTextSize = screenWidth * 0.03;
    final iconButtonSize = screenWidth * 0.04;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                color: getErrorColor(context).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: getErrorColor(context).withOpacity(0.3)),
              ),
              child: Icon(
                Icons.error_outline,
                size: iconSize,
                color: getErrorColor(context),
              ),
            ),
            SizedBox(height: screenHeight * 0.015),
            Text(
              'App Initialization Error',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                color: getPrimaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.01),
            Container(
              padding: EdgeInsets.all(screenWidth * 0.02),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceContainerLow(context),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.getBorderLight(context)),
              ),
              child: Text(
                controller.errorMessage ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: messageSize,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
            SizedBox(height: screenHeight * 0.015),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.initializeApp,
                  icon: Icon(Icons.refresh, size: iconButtonSize),
                  label: Text(
                    'Retry',
                    style: TextStyle(fontSize: buttonTextSize),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: getPrimaryColor(context),
                    foregroundColor: AppColors.getTextInverse(context),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.02,
                      vertical: screenHeight * 0.005,
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                TextButton.icon(
                  onPressed: controller.toggleLogs,
                  icon: Icon(
                    Icons.bug_report,
                    size: iconButtonSize,
                    color: AppColors.getTextPrimary(context),
                  ),
                  label: Text(
                    'View Logs',
                    style: TextStyle(
                      fontSize: buttonTextSize,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QuranLogsPanel extends StatelessWidget {
  const QuranLogsPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SttController>();
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final panelHeight = screenHeight * 0.1875; // âœ… ~150px pada 800px
    final iconSize = screenWidth * 0.04; // âœ… ~16px
    final titleSize = screenWidth * 0.03;
    final logFontSize = screenWidth * 0.02; // âœ… ~8px
    final paddingH = screenWidth * 0.02; // âœ… ~8px
    final paddingV = screenHeight * 0.0075; // âœ… ~6px

    return Container(
      height: panelHeight,
      decoration: BoxDecoration(
        color: AppColors.getTextPrimary(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: paddingH,
              vertical: paddingV,
            ),
            decoration: BoxDecoration(
              color: AppColors.getTextPrimary(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, color: getCorrectColor(context), size: iconSize),
                SizedBox(width: screenWidth * 0.01),
                Text(
                  'API Debug Console',
                  style: TextStyle(
                    color: AppColors.getTextInverse(context),
                    fontWeight: FontWeight.bold,
                    fontSize: titleSize,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.clear, color: AppColors.getTextInverse(context), size: iconSize),
                  onPressed: controller.clearLogs,
                ),
                IconButton(
                  icon: Icon(
                    Icons.save_alt,
                    color: AppColors.getTextInverse(context),
                    size: iconSize,
                  ),
                  onPressed: () => controller.exportSession(context),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.getTextInverse(context), size: iconSize),
                  onPressed: controller.toggleLogs,
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: controller.appLogger.logs,
              builder: (context, logs, child) {
                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.all(screenWidth * 0.01),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final logIndex = logs.length - 1 - index;
                    final log = logs[logIndex];
                    Color logColor = AppColors.getSuccess(context);
                    if (log.contains('ERROR') || log.contains('Failed'))
                      logColor = AppColors.getError(context);
                    else if (log.contains('WARNING') || log.contains('Warning'))
                      logColor = AppColors.getWarning(context);
                    else if (log.contains('API_') || log.contains('WEBSOCKET'))
                      logColor = AppColors.getInfo(context);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: logColor,
                          fontSize: logFontSize,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void showCompletionDialog(BuildContext context, SttController controller) {
  if (!context.mounted) return;

  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  final iconSize = screenWidth * 0.06;
  final titleSize = screenWidth * 0.045;
  final congratsSize = screenWidth * 0.05;
  final messageSize = screenWidth * 0.035;
  final statLabelSize = screenWidth * 0.03;
  final statValueSize = screenWidth * 0.035;

  final sessionDuration = controller.sessionStartTime != null
      ? DateTime.now().difference(controller.sessionStartTime!).inMinutes
      : 0;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: AppColors.getSurface(context),
        title: Row(
          children: [
            Icon(Icons.celebration, color: getCorrectColor(context), size: iconSize),
            SizedBox(width: screenWidth * 0.02),
            Text(
              'Surah Completed!',
              style: TextStyle(
                fontSize: titleSize,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: getCorrectColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'ðŸŽ‰ Congratulations! ðŸŽ‰',
                    style: TextStyle(
                      fontSize: congratsSize,
                      fontWeight: FontWeight.bold,
                      color: getPrimaryColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'You have completed reading ${controller.suratNameSimple}',
                    style: TextStyle(
                      fontSize: messageSize,
                      color: AppColors.getTextPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  Column(
                    children: [
                      _buildStatItem(
                        context,
                        'Ayat',
                        '${controller.ayatList.length}',
                        statLabelSize,
                        statValueSize,
                      ),
                      _buildStatItem(
                        context,
                        'Time',
                        '${sessionDuration}min',
                        statLabelSize,
                        statValueSize,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: getPrimaryColor(context)),
            child: Text('Finish', style: TextStyle(color: AppColors.getTextInverse(context))),
          ),
        ],
      );
    },
  );
}

Widget _buildStatItem(
  BuildContext context,
  String label,
  String value,
  double labelSize,
  double valueSize,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: labelSize, color: AppColors.getTextSecondary(context)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: FontWeight.bold,
            color: getPrimaryColor(context),
          ),
        ),
      ],
    ),
  );
}

void showSimpleSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
}) {
  if (!ScaffoldMessenger.of(context).mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.getTextInverse(context),
        ),
      ),
      backgroundColor: backgroundColor ?? getPrimaryColor(context),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}
