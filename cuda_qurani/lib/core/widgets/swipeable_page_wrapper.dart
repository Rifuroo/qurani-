// lib/core/widgets/swipeable_page_wrapper.dart

import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/design_system/app_design_system.dart';
import 'package:cuda_qurani/screens/main/home/screens/home_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/surah_list_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/completion_page.dart';
import 'package:cuda_qurani/screens/main/home/screens/activity_page.dart';

/// SwipeablePageWrapper - Wrapper widget yang mendeteksi horizontal swipe gesture
/// dan trigger navigasi antar main pages dengan smooth animation
class SwipeablePageWrapper extends StatefulWidget {
  final Widget child;
  final int currentPageIndex;
  
  const SwipeablePageWrapper({
    Key? key,
    required this.child,
    required this.currentPageIndex,
  }) : super(key: key);

  @override
  State<SwipeablePageWrapper> createState() => _SwipeablePageWrapperState();
}

class _SwipeablePageWrapperState extends State<SwipeablePageWrapper> {
  // ==================== CONFIGURATION ====================
  
  /// Velocity threshold (pixels/second) - turunkan untuk swipe lebih sensitif
  static const double _velocityThreshold = 300.0;
  
  /// Swipe distance threshold (pixels) - minimum distance untuk trigger swipe
  static const double _swipeThreshold = 80.0;
  
  /// Main pages yang bisa di-swipe dengan index mapping
  static const List<int> _mainPageIndices = [0, 1, 2, 4]; // Home, Quran, Completion, Activity
  
  /// Page mapping untuk navigation
  static const Map<int, String> _pageNames = {
    0: 'Home',
    1: 'Quran',
    2: 'Completion', 
    4: 'Activity',
  };

  // ==================== SWIPE DETECTION ====================
  
  double _dragStartX = 0.0;
  bool _isDragging = false;

  void _handleDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _isDragging = true;
    
    print('🎯 SwipeablePageWrapper: Drag started at ${_dragStartX.toStringAsFixed(1)}');
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    final currentX = details.globalPosition.dx;
    final deltaX = currentX - _dragStartX;
    
    // Optional: Add visual feedback here (like edge glow effect)
    // print('📱 Dragging: deltaX = ${deltaX.toStringAsFixed(1)}');
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    
    _isDragging = false;
    
    final velocity = details.primaryVelocity ?? 0.0;
    
    print('🚀 SwipeablePageWrapper: Drag ended');
    print('   Velocity: ${velocity.toStringAsFixed(1)} px/s');
    print('   Threshold: $_velocityThreshold px/s');
    print('   Current page: ${widget.currentPageIndex} (${_pageNames[widget.currentPageIndex]})');
    
    // Check if velocity meets threshold
    if (velocity.abs() < _velocityThreshold) {
      print('⚠️ Swipe too slow: ${velocity.abs().toStringAsFixed(1)} < $_velocityThreshold');
      return;
    }
    
    // Determine swipe direction
    int direction;
    if (velocity > 0) {
      // Swipe RIGHT = Previous page
      direction = -1;
      print('👈 Swiping RIGHT (previous page)');
    } else {
      // Swipe LEFT = Next page
      direction = 1;
      print('👉 Swiping LEFT (next page)');
    }
    
    _navigateToPage(direction);
  }

  // ==================== NAVIGATION LOGIC ====================
  
  void _navigateToPage(int direction) {
    final currentMainIndex = _mainPageIndices.indexOf(widget.currentPageIndex);
    
    if (currentMainIndex == -1) {
      print('❌ Current page ${widget.currentPageIndex} is not a main page, swipe ignored');
      return;
    }
    
    // Calculate new page index with wrapping
    int newMainIndex;
    if (direction == -1) {
      // Previous page (wrap to last if at first)
      newMainIndex = currentMainIndex > 0 
          ? currentMainIndex - 1 
          : _mainPageIndices.length - 1;
    } else {
      // Next page (wrap to first if at last)
      newMainIndex = currentMainIndex < _mainPageIndices.length - 1 
          ? currentMainIndex + 1 
          : 0;
    }
    
    final newPageIndex = _mainPageIndices[newMainIndex];
    
    print('🎯 Navigating: ${widget.currentPageIndex} → $newPageIndex');
    print('   ${_pageNames[widget.currentPageIndex]} → ${_pageNames[newPageIndex]}');
    
    // Haptic feedback
    AppHaptics.light();
    
    // Navigate with smooth animation
    _performNavigation(newPageIndex, direction);
  }

  void _performNavigation(int targetPageIndex, int direction) {
    if (!mounted) return;
    
    // Get target page widget
    Widget targetPage;
    switch (targetPageIndex) {
      case 0:
        targetPage = const HomePage();
        break;
      case 1:
        targetPage = const SurahListPage();
        break;
      case 2:
        targetPage = const CompletionPage();
        break;
      case 4:
        targetPage = const ActivityPage();
        break;
      default:
        print('❌ Unknown target page index: $targetPageIndex');
        return;
    }

    // Navigate with slide animation
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide animation based on swipe direction
          final begin = direction == 1 
              ? const Offset(1.0, 0.0)  // Slide from right (swipe left)
              : const Offset(-1.0, 0.0); // Slide from left (swipe right)
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          var offsetAnimation = animation.drive(tween);

          // Add fade for extra smoothness
          var fadeAnimation = animation.drive(
            Tween(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: curve),
            ),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: offsetAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
      (route) => false, // Clear navigation stack
    );
  }

  // ==================== BUILD METHOD ====================
  
  @override
  Widget build(BuildContext context) {
    // Only enable swipe for main pages
    final isMainPage = _mainPageIndices.contains(widget.currentPageIndex);
    
    if (!isMainPage) {
      print('ℹ️ SwipeablePageWrapper: Page ${widget.currentPageIndex} is not swipeable');
      return widget.child;
    }
    
    return GestureDetector(
      // ✅ CRITICAL: Use translucent to allow child widgets to receive gestures too
      behavior: HitTestBehavior.translucent,
      
      // Horizontal drag detection
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      
      child: widget.child,
    );
  }
}

/// Extension untuk mudah wrap any page dengan swipe functionality
extension SwipeablePageExtension on Widget {
  /// Wrap widget dengan SwipeablePageWrapper
  Widget makeSwipeable(int currentPageIndex) {
    return SwipeablePageWrapper(
      currentPageIndex: currentPageIndex,
      child: this,
    );
  }
}