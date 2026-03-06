// lib\screens\main\stt\widgets\quran_widgets.dart
import 'dart:async';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import 'package:cuda_qurani/core/utils/language_helper.dart';
import 'package:cuda_qurani/main.dart';
import 'package:cuda_qurani/models/playback_settings_model.dart';
import 'package:cuda_qurani/screens/main/home/screens/settings/settings_page.dart';
import 'package:cuda_qurani/screens/main/stt/widgets/playback_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/stt_controller.dart';
import 'ayah_search_modal.dart';

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

  // Helper function untuk AppBar colors
  Color _getAppBarBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? AppColors.getSurfaceVariant(context)
        : AppColors.getPrimary(context);
  }

  Color _getAppBarTextColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? AppColors.getTextPrimary(context)
        : AppColors.getTextInverse(context);
  }

  void _showLayoutPicker(BuildContext context) {
    final controller = context.read<SttController>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getSurface(context),
        title: Text(
          LanguageHelper.tr(
            _translations,
            'app_bar_actions.layout_picker_title',
          ),
          style: TextStyle(
            fontSize: 16,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MushafLayout.values.map((layout) {
            final isSelected = controller.mushafLayout == layout;
            return RadioListTile<MushafLayout>(
              title: Text(
                '${layout.displayName} (${layout.totalPages} ${LanguageHelper.tr(_translations, 'app_bar_actions.layout_pages_suffix')})',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              subtitle: Text(
                layout.isGlyphBased
                    ? LanguageHelper.tr(
                        _translations,
                        'app_bar_actions.layout_glyph_desc',
                      )
                    : LanguageHelper.tr(
                        _translations,
                        'app_bar_actions.layout_font_desc',
                      ),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              value: layout,
              groupValue: controller.mushafLayout,
              onChanged: (value) {
                if (value != null) {
                  Navigator.of(ctx).pop();
                  controller.switchMushafLayout(value);
                }
              },
              selected: isSelected,
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              LanguageHelper.tr(_translations, 'app_bar_actions.cancel_text'),
              style: TextStyle(color: AppColors.getTextPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTranslations() async {
    // Ganti path sesuai file JSON yang dibutuhkan
    final trans = await context.loadTranslations('stt');
    setState(() {
      _translations = trans;
    });
  }

  Widget _buildSeparator(BuildContext context, double screenHeight) {
    return Container(
      width: 1,
      height: screenHeight * 0.016,
      color: _getAppBarTextColor(context).withOpacity(0.3),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ GUNAKAN READ: Agar build tidak terpanggil berulang kali saat scroll
    final controller = context.read<SttController>();

    final isUIVisible = context.select<SttController, bool>(
      (c) => c.isUIVisible,
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final iconSize = screenWidth * 0.050; // Increased
    final titleSize = screenWidth * 0.028; // Increased
    final subtitleSize = screenWidth * 0.028; // Increased
    final badgeSize = screenWidth * 0.028; // Increased

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isUIVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !isUIVisible,
        child: AppBar(
          backgroundColor: _getAppBarBackgroundColor(context),
          foregroundColor: _getAppBarTextColor(context),
          toolbarHeight: kToolbarHeight,
          leading: IconButton(
            icon: Icon(
              Icons.menu,
              size: iconSize * 1.2,
              color: _getAppBarTextColor(context),
            ),
            onPressed: () => Navigator.pop(context),
          ),

          title: Transform.translate(
            offset: const Offset(-3, 0), // <--- BIAR MINUS DI SINI BANG!
            child: ValueListenableBuilder<PageDisplayData>(
              valueListenable: controller.appBarNotifier,
              builder: (context, data, _) {
                return Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/qurani-white-text.png',
                        height: screenHeight * 0.020, // Gedein dikit bang
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                      SizedBox(height: screenHeight * 0.007),

                      // Info Row with structured layout
                      Row(
                        children: [
                          // Surah Name
                          Text(
                            data.surahName,
                            style: TextStyle(
                              fontSize: titleSize, // Reverted to full size
                              fontWeight: FontWeight.bold,
                              color: _getAppBarTextColor(context),
                              height: 1.1,
                            ),
                          ),

                          _buildSeparator(context, screenHeight),
                          const SizedBox(width: 4),

                          // Juz Badge
                          Text(
                            '${LanguageHelper.tr(_translations, "app_bar.juz_text")} ${context.formatNumber(data.juzNumber)}',
                            style: TextStyle(
                              fontSize: badgeSize, // Gedein dikit bang
                              fontWeight: FontWeight.w500,
                              color: _getAppBarTextColor(
                                context,
                              ).withOpacity(0.9),
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(width: 4),
                          _buildSeparator(context, screenHeight),
                          const SizedBox(width: 4),

                          // Page Number
                          Text(
                            '${LanguageHelper.tr(_translations, "app_bar.page_text")} ${context.formatNumber(data.pageNumber)}',
                            style: TextStyle(
                              fontSize: subtitleSize, // Gedein dikit bang
                              fontWeight: FontWeight.w500,
                              color: _getAppBarTextColor(
                                context,
                              ).withOpacity(0.9),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          titleSpacing: 0,

          // ✅ ACTIONS: Options moved from Floating Button + Search, Settings
          actions: [
            // Search
            IconButton(
              onPressed: () => AyahSearchModal.show(context),
              icon: Icon(
                Icons.search,
                size: iconSize * 1,
                color: _getAppBarTextColor(context),
              ),
              splashRadius: iconSize,
              tooltip: LanguageHelper.tr(
                _translations,
                'app_bar_actions.search_tooltip',
              ),
            ),

            // Settings
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
              ),
              icon: Icon(
                Icons.settings,
                size: iconSize * 1,
                color: _getAppBarTextColor(context),
              ),
              splashRadius: iconSize,
              tooltip: LanguageHelper.tr(
                _translations,
                'app_bar_actions.settings_tooltip',
              ),
            ),

            PopupMenuButton<String>(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.getSurface(context)
                  : Colors.white,
              surfaceTintColor: Colors.transparent,
              icon: Icon(
                Icons.more_vert,
                size: iconSize * 1.0,
                color: _getAppBarTextColor(context),
              ),
              padding: EdgeInsets.zero,
              tooltip: LanguageHelper.tr(
                _translations,
                'app_bar_actions.menu_tooltip',
              ),
              onSelected: (value) {
                switch (value) {
                  case 'bookmark':
                    Scaffold.of(context).openEndDrawer();
                    break;
                  case 'view_mode':
                    controller.toggleQuranMode();
                    break;
                  case 'visibility':
                    controller.toggleHideUnread();
                    break;
                }
              },
              itemBuilder: (context) => [
                // Bookmark
                PopupMenuItem(
                  value: 'bookmark',
                  child: Row(
                    children: [
                      Icon(
                        Icons.bookmark_outline,
                        size: 20,
                        color: AppColors.getPrimary(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        LanguageHelper.tr(
                          _translations,
                          'app_bar_actions.bookmark_text',
                        ),
                      ),
                    ],
                  ),
                ),
                // View Mode
                PopupMenuItem(
                  value: 'view_mode',
                  child: Row(
                    children: [
                      Icon(
                        context.select<SttController, bool>(
                              (c) => c.isQuranMode,
                            )
                            ? Icons.auto_stories
                            : Icons.vertical_split,
                        size: 20,
                        color: AppColors.getPrimary(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        LanguageHelper.tr(
                          _translations,
                          'app_bar_actions.view_mode_text',
                        ),
                      ),
                    ],
                  ),
                ),
                // Visibility
                PopupMenuItem(
                  value: 'visibility',
                  child: Row(
                    children: [
                      Icon(
                        context.select<SttController, bool>(
                              (c) => c.hideUnreadAyat,
                            )
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 20,
                        color: AppColors.getPrimary(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        LanguageHelper.tr(
                          _translations,
                          'app_bar_actions.visibility_text',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
  double _dragPosition = 0.0;
  String? _activeMode;
  bool _isDragging = false;
  DateTime _lastActivityTime = DateTime.now();

  // Wiggle animation for idle hint
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;
  Timer? _idleTimer;
  bool _isWiggling = false;
  bool _isSessionActive = false; // Tracks listening/recording state

  Map<String, dynamic> _translations = {};

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('stt');
    if (mounted) {
      setState(() {
        _translations = trans;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTranslations();

    // Wiggle: slow breathing oscillation
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _wiggleAnimation = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _wiggleController, curve: Curves.easeInOutSine),
    );
    _wiggleController.addListener(() {
      if (mounted && _isWiggling) setState(() {});
    });

    // Start idle timer on launch
    _scheduleIdleWiggle();
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    _idleTimer?.cancel();
    super.dispose();
  }

  void _scheduleIdleWiggle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 2), () {
      if (mounted &&
          !_isDragging &&
          _activeMode == null &&
          _dragPosition == 0.0 &&
          !_isSessionActive) {
        _startWiggle();
      }
    });
  }

  void _startWiggle() {
    if (_isWiggling || _isSessionActive) return;
    _isWiggling = true;
    _wiggleController.repeat(reverse: true);
  }

  void _stopWiggle() {
    if (!_isWiggling) return;
    _isWiggling = false;
    _wiggleController.stop();
    _wiggleController.reset();
  }

  void _handleDragUpdate(
    double delta,
    double maxWidth,
    SttController controller,
  ) {
    final isListening = controller.isListeningMode;
    final isRecording = controller.isRecording;
    final isPaused = controller.isPaused;

    // ✅ Calculate new position first
    double newPosition = _dragPosition + (delta / maxWidth);

    // ✅ Apply constraints based on mode
    if (isRecording) {
      // Recording: block ALL drag — user must tap center to stop
      return;
    } else if (isListening && !isPaused) {
      // Playing: only allow left drag (re-open settings)
      newPosition = newPosition.clamp(-1.0, 0.0);
    } else {
      // Idle / Paused: free drag both directions
      newPosition = newPosition.clamp(-1.0, 1.0);
    }

    // ✅ Single setState for smooth drag
    if (mounted) {
      _stopWiggle();
      setState(() {
        _isDragging = true;
        _dragPosition = newPosition;
        _lastActivityTime = DateTime.now();
      });
    }
  }

  Future<void> _handleDragEnd(SttController controller) async {
    const threshold = 0.85;

    // ✅ Store values before any async operations
    final dragPos = _dragPosition;
    final isListening = controller.isListeningMode;
    final isRecording = controller.isRecording;
    final isPaused = controller.isPaused;

    // ✅ Reset drag state immediately
    if (mounted) {
      setState(() {
        _isDragging = false;
      });
      _scheduleIdleWiggle();
    }

    // ✅ Handle drag actions
    if (isListening && !isPaused) {
      // Playing: can only re-open settings (left drag)
      if (dragPos < -threshold) {
        await _activateMode('listen', controller);
      } else {
        _resetToCenter();
      }
    } else if (isRecording) {
      // Recording: any drag just resets
      _resetToCenter();
    } else {
      // Idle/Paused: full functionality
      if (dragPos < -threshold) {
        await _activateMode('listen', controller);
      } else if (dragPos > threshold) {
        await _activateMode('recite', controller);
      } else {
        _resetToCenter();
      }
    }
  }

  Future<void> _activateMode(String mode, SttController controller) async {
    AppHaptics.medium();

    if (mounted) {
      setState(() {
        _activeMode = mode;
      });
    }

    if (mode == 'listen') {
      // Reset position before opening settings
      _resetToCenter(keepActiveMode: true);

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
          _resetToCenter(keepActiveMode: false);
        }
      } else {
        _resetToCenter(keepActiveMode: false);
      }
    } else if (mode == 'recite') {
      // Stop listening first if active
      if (controller.isListeningMode) {
        await controller.stopListening();
      }

      await controller.startRecording();
      _resetToCenter(keepActiveMode: false);
    }
  }

  void _resetToCenter({bool keepActiveMode = false}) {
    if (mounted) {
      setState(() {
        _dragPosition = 0.0;
        _isDragging = false;
        if (!keepActiveMode) {
          _activeMode = null;
        }
      });
      // Re-schedule wiggle after reset (if session ended)
      if (!keepActiveMode) _scheduleIdleWiggle();
    }
  }

  Future<void> _handleCenterButtonTap(SttController controller) async {
    AppHaptics.light();

    // Ensure center position
    if (_dragPosition != 0.0 && mounted) {
      setState(() {
        _dragPosition = 0.0;
      });
    }

    if (controller.isListeningMode) {
      // ✅ RELIABLE TOGGLE using controller's getter
      // Fixed: Pause button wasn't working because service was accessed directly
      if (controller.isPaused) {
        await controller.resumeListening();
      } else {
        await controller.pauseListening();
      }
    } else if (controller.isRecording) {
      await controller.stopRecording();
    }
  }

  Widget _buildThumbIcon(
    SttController controller,
    bool isListening,
    bool isRecording,
    bool isPaused,
    double iconSize,
  ) {
    IconData icon;
    String keyState;

    if (isListening) {
      icon = isPaused ? Icons.play_arrow : Icons.pause;
      keyState = 'listen_${isPaused ? 'paused' : 'playing'}';
    } else if (isRecording) {
      icon = Icons.stop;
      keyState = 'recording';
    } else if (_isDragging) {
      if (_dragPosition < -0.5) {
        icon = Icons.play_arrow;
        keyState = 'drag_listen';
      } else if (_dragPosition > 0.5) {
        icon = Icons.mic;
        keyState = 'drag_recite';
      } else {
        icon = Icons.code;
        keyState = 'drag_center';
      }
    } else {
      icon = Icons.code;
      keyState = 'idle';
    }

    return Icon(
      icon,
      key: ValueKey(keyState),
      color: AppColors.getTextInverse(context),
      size: iconSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SttController>();

    final isUIVisible = context.select<SttController, bool>(
      (c) => c.isUIVisible,
    );
    final isListening = context.select<SttController, bool>(
      (c) => c.isListeningMode,
    );
    final isRecording = context.select<SttController, bool>(
      (c) => c.isRecording,
    );
    final isPaused = context.select<SttController, bool>((c) => c.isPaused);
    final isOverlayVisible = context.select<SttController, bool>(
      (c) => c.isOverlayVisible,
    );

    // ✅ Track session state for wiggle guard (includes paused)
    _isSessionActive = isListening || isRecording;

    // Force center only when actively playing/recording (NOT when paused)
    final shouldLockCenter = isRecording || (isListening && !isPaused);
    if (shouldLockCenter && _dragPosition != 0.0 && !_isDragging) {
      _dragPosition = 0.0;
    }

    // Stop wiggle when any session is active (including paused) or overlay is visible
    if (_isSessionActive ||
        _isDragging ||
        _activeMode != null ||
        isOverlayVisible) {
      _lastActivityTime = DateTime.now();
      _stopWiggle();
    }

    // Reset active mode if session ended
    if (_activeMode == 'listen' && !isListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetToCenter(keepActiveMode: false);
      });
    }
    if (_activeMode == 'recite' && !isRecording) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetToCenter(keepActiveMode: false);
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

    // ✅ Compute position: forced 0 when actively playing/recording, free when paused/idle
    final double wiggleOffset = _isWiggling ? _wiggleAnimation.value : 0.0;
    final effectivePosition =
        (shouldLockCenter || _activeMode != null) && !_isDragging
        ? 0.0
        : (_dragPosition + wiggleOffset).clamp(-1.0, 1.0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isUIVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !isUIVisible,
        child: SizedBox(
          height: containerHeight,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Main Slider Track
              Positioned(
                bottom: bottomOffset,
                child: GestureDetector(
                  onPanStart: (_) {
                    if (mounted) setState(() => _isDragging = true);
                  },
                  onPanUpdate: (details) {
                    _handleDragUpdate(
                      details.delta.dx,
                      trackWidth / 2,
                      controller,
                    );
                  },
                  onPanEnd: (details) {
                    _handleDragEnd(controller);
                  },
                  onTapDown: (details) {
                    // ✅ TAP TO JUMP: Allow jumping to positions (clamped by mode)
                    final localX = details.localPosition.dx;
                    final centeredX = localX - (trackWidth / 2);
                    final targetPos = (centeredX / (trackWidth / 2)).clamp(
                      -1.0,
                      1.0,
                    );
                    _handleDragUpdate(
                      targetPos * (trackWidth / 2) -
                          _dragPosition * (trackWidth / 2),
                      trackWidth / 2,
                      controller,
                    );
                    // Force commit if it's a tap
                    Future.microtask(() => _handleDragEnd(controller));
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: trackWidth,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceContainerMedium(context),
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.getShadowMedium(context),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Left Label (Listen) with parallax
                        Positioned(
                          left: trackWidth * 0.08,
                          child: Transform.translate(
                            offset: Offset(-_dragPosition * 8, 0),
                            child: GestureDetector(
                              onTap: isRecording
                                  ? null
                                  : () => _activateMode('listen', controller),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _dragPosition < -0.3 || isListening
                                    ? 1.0
                                    : 0.4,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      size: iconSize * 0.9,
                                      color: isListening
                                          ? AppColors.getPrimary(context)
                                          : AppColors.getTextPrimary(context),
                                    ),
                                    const SizedBox(width: 6),
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
                                        color: isListening
                                            ? AppColors.getPrimary(context)
                                            : AppColors.getTextPrimary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Right Label (Recite) with parallax
                        Positioned(
                          right: trackWidth * 0.08,
                          child: Transform.translate(
                            offset: Offset(-_dragPosition * 8, 0),
                            child: GestureDetector(
                              onTap: isRecording || (isListening && !isPaused)
                                  ? null
                                  : () => _activateMode('recite', controller),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _dragPosition > 0.3 || isRecording
                                    ? 1.0
                                    : 0.4,
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
                                        color: isRecording
                                            ? AppColors.getError(context)
                                            : AppColors.getTextPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.mic_rounded,
                                      size: iconSize * 0.9,
                                      color: isRecording
                                          ? AppColors.getError(context)
                                          : AppColors.getTextPrimary(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ✅ Sliding Thumb — direct Positioned + ripple
                        Positioned(
                          left:
                              ((trackWidth / 2) - (thumbSize / 2)) +
                              (effectivePosition *
                                  (trackWidth / 2 - thumbSize / 2)),
                          child: AnimatedScale(
                            scale: _isDragging ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            child: Material(
                              color: _getThumbColor(isListening, isRecording),
                              shape: const CircleBorder(),
                              elevation: _isDragging ? 8 : 4,
                              shadowColor: _getThumbColor(
                                isListening,
                                isRecording,
                              ).withValues(alpha: 0.4),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                splashColor: Colors.white.withValues(
                                  alpha: 0.3,
                                ),
                                highlightColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                onTap: () => _handleCenterButtonTap(controller),
                                child: SizedBox(
                                  width: thumbSize,
                                  height: thumbSize,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      switchInCurve: Curves.easeOut,
                                      switchOutCurve: Curves.easeIn,
                                      transitionBuilder: (child, animation) {
                                        return ScaleTransition(
                                          scale: animation,
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _buildThumbIcon(
                                        controller,
                                        isListening,
                                        isRecording,
                                        isPaused,
                                        iconSize,
                                      ),
                                    ),
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

              // Settings Button for Listen Mode
              if (isListening && !_isDragging)
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
                                      initialSurahId: controller.activeSurahId,
                                      initialVerse: controller.activeAyahNumber,
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
    if (isListening) return AppColors.getPrimary(context);
    if (isRecording) return AppColors.getError(context);

    // During drag, show preview color
    if (_isDragging) {
      if (_dragPosition < -0.3) {
        return AppColors.getPrimary(context).withOpacity(0.7);
      }
      if (_dragPosition > 0.3) {
        return AppColors.getError(context).withOpacity(0.7);
      }
    }

    return AppColors.getTextTertiary(context);
  }
}

class QuranLoadingWidget extends StatefulWidget {
  final String errorMessage;
  const QuranLoadingWidget({Key? key, required this.errorMessage})
    : super(key: key);

  @override
  State<QuranLoadingWidget> createState() => _QuranLoadingWidgetState();
}

class _QuranLoadingWidgetState extends State<QuranLoadingWidget> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('stt');
    if (mounted) {
      setState(() {
        _translations = trans;
      });
    }
  }

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
              color: AppColors.getPrimary(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.getTextInverse(context),
                ),
                strokeWidth: 2,
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.015),
          Text(
            LanguageHelper.tr(_translations, 'initialization.title'),
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
              color: AppColors.getPrimary(context),
            ),
          ),
          SizedBox(height: screenHeight * 0.005),
          Text(
            widget.errorMessage.isNotEmpty
                ? widget.errorMessage
                : LanguageHelper.tr(
                    _translations,
                    'initialization.loading_data',
                  ),
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

class QuranErrorWidget extends StatefulWidget {
  const QuranErrorWidget({Key? key}) : super(key: key);

  @override
  State<QuranErrorWidget> createState() => _QuranErrorWidgetState();
}

class _QuranErrorWidgetState extends State<QuranErrorWidget> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('stt');
    if (mounted) {
      setState(() {
        _translations = trans;
      });
    }
  }

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
                color: AppColors.getError(context).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.getError(context).withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons.error_outline,
                size: iconSize,
                color: AppColors.getError(context),
              ),
            ),
            SizedBox(height: screenHeight * 0.015),
            Text(
              LanguageHelper.tr(_translations, 'initialization.error_title'),
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                color: AppColors.getPrimary(context),
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
                controller.errorMessage ??
                    LanguageHelper.tr(
                      _translations,
                      'initialization.unknown_error',
                    ),
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
                    LanguageHelper.tr(
                      _translations,
                      'initialization.retry_button',
                    ),
                    style: TextStyle(fontSize: buttonTextSize),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getPrimary(context),
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
                    LanguageHelper.tr(
                      _translations,
                      'initialization.logs_button',
                    ),
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

class QuranLogsPanel extends StatefulWidget {
  const QuranLogsPanel({Key? key}) : super(key: key);

  @override
  State<QuranLogsPanel> createState() => _QuranLogsPanelState();
}

class _QuranLogsPanelState extends State<QuranLogsPanel> {
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('stt');
    if (mounted) {
      setState(() {
        _translations = trans;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SttController>();
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final panelHeight = screenHeight * 0.1875;
    final iconSize = screenWidth * 0.04;
    final titleSize = screenWidth * 0.03;
    final logFontSize = screenWidth * 0.02;
    final paddingH = screenWidth * 0.02;
    final paddingV = screenHeight * 0.0075;

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
                Icon(
                  Icons.terminal,
                  color: AppColors.getSuccess(context),
                  size: iconSize,
                ),
                SizedBox(width: screenWidth * 0.01),
                Text(
                  LanguageHelper.tr(_translations, 'logs.console_title'),
                  style: TextStyle(
                    color: AppColors.getTextInverse(context),
                    fontWeight: FontWeight.bold,
                    fontSize: titleSize,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppColors.getTextInverse(context),
                    size: iconSize,
                  ),
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
                  icon: Icon(
                    Icons.close,
                    color: AppColors.getTextInverse(context),
                    size: iconSize,
                  ),
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

void showCompletionDialog(
  BuildContext context,
  SttController controller,
) async {
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

  final Map<String, dynamic> translations = await context.loadTranslations(
    'stt',
  );

  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: AppColors.getSurface(context),
        title: Row(
          children: [
            Icon(
              Icons.celebration,
              color: AppColors.getSuccess(context),
              size: iconSize,
            ),
            SizedBox(width: screenWidth * 0.02),
            Text(
              LanguageHelper.tr(translations, 'dialogs.completion_title'),
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
                color: AppColors.getSuccess(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    LanguageHelper.tr(translations, 'dialogs.congratulations'),
                    style: TextStyle(
                      fontSize: congratsSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    '${LanguageHelper.tr(translations, "dialogs.completed_reading")} ${controller.suratNameSimple}',
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
                        LanguageHelper.tr(translations, 'dialogs.stat_ayah'),
                        '${controller.ayatList.length}',
                        statLabelSize,
                        statValueSize,
                      ),
                      _buildStatItem(
                        context,
                        LanguageHelper.tr(translations, 'dialogs.stat_time'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getPrimary(context),
            ),
            child: Text(
              LanguageHelper.tr(translations, 'dialogs.finish_button'),
              style: TextStyle(color: AppColors.getTextInverse(context)),
            ),
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
          style: TextStyle(
            fontSize: labelSize,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: FontWeight.bold,
            color: AppColors.getPrimary(context),
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
      backgroundColor: backgroundColor ?? AppColors.getPrimary(context),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}
