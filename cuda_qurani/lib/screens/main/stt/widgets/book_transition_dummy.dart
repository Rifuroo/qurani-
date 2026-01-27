import 'package:flutter/material.dart';
import 'dart:math';

/// A widget that applies a 3D book-flip effect based on the PageController's position.
/// It must be wrapped in an AnimatedBuilder listening to the controller.
class BookTransition extends StatelessWidget {
  final Widget child;
  final int index;
  final PageController controller;
  final bool isReverse; // For RTL (e.g., Quran)

  const BookTransition({
    Key? key,
    required this.child,
    required this.index,
    required this.controller,
    this.isReverse = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If controller not attached yet, just show child
    if (!controller.hasClients || controller.position.context.storageContext == null) {
      return child;
    }

    // Current page scroll position
    double page = controller.page ?? controller.initialPage.toDouble();
    
    // Calculate difference (0 means current page is fully visible)
    // For RTL (reverse: true):
    // Index 0 is the "last" page visually (rightmost).
    // Scrolled value increases as we go left (to higher visual indices).
    // Wait, PageView(reverse: true) means:
    // Index 0 is at offset 0.
    // Index 1 is at offset 1.
    // So logic is standard, just visual rendering is reversed.
    
    double diff = page - index;

    // We only transform pages that are transitioning (diff between -1 and 1)
    if (diff > 1 || diff < -1) {
       // Hide pages that are far away to prevent glitching?
       // Actually PageView doesn't build them usually.
       // But if we use implicitScrolling, they might be built.
       return child;
    }

    // Rotation angle
    // As diff goes 0 -> 1 (page N goes left), we want it to rotate like a book page.
    // If reverse=true (RTL), scrolling from 0 -> 1 means dragging Right Page to Left?
    // Let's verify standard behavior first.
    
    // Simple 3D rotation
    return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(diff * -1.5), // Adjust 1.5 for intensity
            alignment: diff > 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: child,
          );
  }
}
