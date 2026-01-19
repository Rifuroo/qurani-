import 'dart:ui';
import 'package:flutter/material.dart';

class MushafPaperBackground extends StatelessWidget {
  final Widget child;

  const MushafPaperBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return child;
    }

    return Stack(
      children: [
        // Base Paper Texture
        Positioned.fill(
          child: CustomPaint(
            painter: _PaperTexturePainter(),
          ),
        ),
        // Child content (Quran text etc)
        child,
      ],
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // 1. Base Gradient (Clean Parchment with Vertical Gradient effect)
    // begin: centerLeft, end: centerRight creates vertical bands of color
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFF7F2E8), // Left edge: soft cream
          const Color(0xFFFFFFFF), // Mid Left: whiter
          const Color(0xFFFFFFFF), // Mid Right: whiter
          const Color(0xFFF7F2E8), // Right edge: soft cream
        ],
        stops: const [0.0, 0.4, 0.6, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect);
    
    canvas.drawRect(rect, paint);
    
    // 2. Subtle Noise/Texture (Procedural)
    final fiberPaint = Paint()
      ..color = Colors.black.withOpacity(0.005) // Slightly more visible for texture
      ..strokeWidth = 0.5;
    
    final random = _SimpleRandom(42);
    for (int i = 0; i < 2000; i++) { // Fewer dots
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawPoints(
        PointMode.points,
        [Offset(x, y)],
        fiberPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Minimal random for Flutter compatibility if needed
class _SimpleRandom {
  int _seed;
  _SimpleRandom(this._seed);
  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}

