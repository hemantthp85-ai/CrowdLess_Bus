import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/colors.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'dashboard/home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.fastOutSlowIn),
      ),
    );

    _controller.forward();

    // Route to appropriate screen after animation completes
    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    // Listen to Firebase Auth state once to route the user
    final authState = ref.read(authStateProvider);

    authState.when(
      data: (user) {
        if (user != null) {
          _smoothNavigateTo(const HomeScreen());
        } else {
          _smoothNavigateTo(const LoginScreen());
        }
      },
      loading: () {
        // If auth state is still loading, wait another second
        Future.delayed(const Duration(milliseconds: 500), _navigateToNextScreen);
      },
      error: (_, __) {
        // Fallback to login in case of any issues
        _smoothNavigateTo(const LoginScreen());
      },
    );
  }

  void _smoothNavigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xff090D16), AppColors.backgroundDark]
                : [Colors.white, const Color(0xffE6F0FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                // Scaling Animated Logo
                Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _buildLogoGraphic(isDark),
                  ),
                ),
                const SizedBox(height: 24),
                // Sliding text container
                Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Column(
                      children: [
                        Text(
                          'CrowdLess Bus',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AppColors.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Know Before You Board',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: isDark 
                                    ? AppColors.textSecondaryDark 
                                    : AppColors.textSecondaryLight,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                // Bottom indicator
                Opacity(
                  opacity: _opacityAnimation.value * 0.5,
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Text(
                      'SECURE CONNECT • REAL-TIME GPS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Draw custom premium vector bus logo programmatically using standard widgets
  Widget _buildLogoGraphic(bool isDark) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 2,
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing wave
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.03),
                    AppColors.secondary.withOpacity(0.1),
                  ],
                ),
              ),
            ),
            // Bus graphic icon
            const Icon(
              Icons.directions_bus_filled_rounded,
              color: AppColors.primary,
              size: 50,
            ),
            // Floating Occupancy Wifi signal indicator
            Positioned(
              top: 18,
              right: 18,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.sensors_rounded,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
