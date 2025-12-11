import 'package:cuda_qurani/screens/main/auth/login/login_page.dart';
import 'package:cuda_qurani/screens/main/stt/utils/constants.dart' as constants;
import 'package:flutter/material.dart';
// import 'package:cuda_qurani/screens/main/home/surah_list_page.dart'; // Tidak terpakai

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    // Fade in animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    // Scale animation for icon
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    // Slide up animation for logo
    // Nilai 30.0 akan kita skala nanti di 'build' menggunakan 's'
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );
    // Start animation
    _controller.forward();

    // Navigate after animation
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- Responsive Setup ---
    const double designWidth = 406.0;
    final double s = MediaQuery.of(context).size.width / designWidth;
    // --- End Responsive Setup ---

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Quran Icon
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: SizedBox(
                        width: 250 * s,
                        height: 250 * s,
                        child: Center(
                          child: Text(
                            'ﲐ',
                            style: TextStyle(
                              fontFamily: 'surah_names',
                              fontSize: 150 * s,
                              color: constants.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 40 * s),

                  // Animated Logo
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.translate(
                      // Skala nilai slide animation dengan 's'
                      offset: Offset(0, _slideAnimation.value * s),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/qurani-white-text.png',
                            height: 40 * s,
                            color: constants.primaryColor,
                          ),
                          SizedBox(height: 20 * s),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}


