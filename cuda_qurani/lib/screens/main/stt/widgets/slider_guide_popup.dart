// lib/screens/main/stt/widgets/slider_guide_popup.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';

class SliderGuidePopup extends StatefulWidget {
  const SliderGuidePopup({Key? key}) : super(key: key);

  @override
  State<SliderGuidePopup> createState() => _SliderGuidePopupState();
}

class _SliderGuidePopupState extends State<SliderGuidePopup>
    with SingleTickerProviderStateMixin {
  static const String _popupCountKey = 'slider_guide_popup_count';
  static const int _maxShowCount = 3;
  static const int _idleTimeSeconds = 6;

  bool _isVisible = false;
  int _showCount = 0;
  DateTime? _lastInteractionTime;
  Uint8List? _compressedImage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static Uint8List? _cachedCompressedImage; // ✅ STATIC CACHE: Prevent re-compression

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadShowCount();
    
    // ✅ OPTIMIZATION: Check cache first
    if (_cachedCompressedImage != null) {
      _compressedImage = _cachedCompressedImage;
    } else {
      _loadAndCompressImage();
    }
    
    _startIdleDetection();
  }

  void _initAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: AppDesignSystem.durationNormal,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
  }

  Future<void> _loadShowCount() async {
    final prefs = await SharedPreferences.getInstance();
    _showCount = prefs.getInt(_popupCountKey) ?? 0;
  }

  Future<void> _incrementShowCount() async {
    _showCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_popupCountKey, _showCount);
  }

  Future<void> _loadAndCompressImage() async {
    try {
      final ByteData data = await rootBundle.load(
        'assets/images/sliderbutton_guide.jpeg',
      );
      final Uint8List bytes = data.buffer.asUint8List();

      // ✅ FIX: quality harus 0-100, bukan 1000!
      final Uint8List? compressedBytes =
          await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 240,
            minHeight: 180,
            quality: 85, // ✅ UBAH: dari 1000 jadi 85 (valid range: 0-100)
            format: CompressFormat.jpeg,
          );

      // ✅ Handle null result
      if (compressedBytes == null) {
        print('⚠️ Image compression returned null - using original image');
        // Fallback: use original bytes if compression fails
        if (mounted) {
          setState(() {
            _compressedImage = bytes; // Use original uncompressed
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _compressedImage = compressedBytes;
        });
        _cachedCompressedImage = compressedBytes; // ✅ Save to static cache
        print(
          '✅ Image compressed successfully: ${compressedBytes.length} bytes',
        );
      }
    } catch (e, stackTrace) {
      print('❌ Failed to load/compress guide image: $e');
      print('Stack trace: $stackTrace');
      // ✅ Don't set _compressedImage - popup will work without image
    }
  }

  void _startIdleDetection() {
    _lastInteractionTime = DateTime.now();

    // Check idle state every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return false;

      final now = DateTime.now();
      final idleDuration = now.difference(_lastInteractionTime ?? now);

      // Show popup if:
      // 1. User idle for 6 seconds
      // 2. Not currently visible
      // 3. Haven't reached max show count
      if (idleDuration.inSeconds >= _idleTimeSeconds &&
          !_isVisible &&
          _showCount < _maxShowCount) {
        _showPopup();
      }

      return mounted;
    });
  }

  void _showPopup() {
    if (!mounted || _showCount >= _maxShowCount) return;

    setState(() {
      _isVisible = true;
    });

    _animController.forward();
    _incrementShowCount();

    // Auto-hide after 5 seconds
    Future.delayed(const Duration(seconds: 3600), () {
      if (mounted && _isVisible) {
        _hidePopup();
      }
    });
  }

  void _hidePopup() {
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  void _onUserInteraction() {
    _lastInteractionTime = DateTime.now();

    // Hide popup if visible
    if (_isVisible) {
      _hidePopup();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserInteraction(),
      onPointerMove: (_) => _onUserInteraction(),
      child: Stack(children: [if (_isVisible) _buildPopup(context)]),
    );
  }

  Widget _buildPopup(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bottomOffset = screenHeight * 0.16; // Di atas bottom bar
    final cardWidth = screenWidth * 0.70; // Lebih kecil (70% dari 85%)
    final imageHeight = screenHeight * 0.30; // Lebih kecil (8% dari 12%)

    return Positioned(
      bottom: bottomOffset,
      left: (screenWidth - cardWidth) / 2,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: cardWidth,
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(
                  AppDesignSystem.radiusMedium,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.getTextPrimary(context).withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Preview - HAPUS JIKA MASIH BERMASALAH
                  // if (_compressedImage != null)
                  //   ClipRRect(
                  //     borderRadius: BorderRadius.only(
                  //       topLeft: Radius.circular(AppDesignSystem.radiusMedium),
                  //       topRight: Radius.circular(AppDesignSystem.radiusMedium),
                  //     ),
                  //     child: Image.memory(
                  //       _compressedImage!,
                  //       width: cardWidth,
                  //       height: imageHeight,
                  //       fit: BoxFit.cover,
                  //     ),
                  //   ),

                  // Text Content (lebih compact)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDesignSystem.space12,
                      vertical: AppDesignSystem.space10,
                    ),
                    child: Row(
                      children: [
                        // Icon lebih kecil
                        Container(
                          padding: EdgeInsets.all(AppDesignSystem.space6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryWithOpacity(0.0),
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusSmall,
                            ),
                          ),
                          child: FaIcon(
                            FontAwesomeIcons.handPointer,
                            size: 0.03 * screenHeight,
                          ),
                        ),
                        AppMargin.gapHSmall(context),
                        // Text lebih compact
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Quick Guide',
                                style: AppTypography.titleSmall(
                                  context,
                                  weight: AppTypography.semiBold,
                                ),
                              ),
                              SizedBox(height: AppDesignSystem.space2),
                              Text(
                                'Slide left to listen, right to recite',
                                style: AppTypography.captionLarge(
                                  context,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Close button lebih kecil
                        InkWell(
                          onTap: _hidePopup,
                          borderRadius: BorderRadius.circular(
                            AppDesignSystem.radiusRound,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppDesignSystem.space4),
                            child: Icon(
                              Icons.close,
                              size: AppDesignSystem.iconSmall,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
