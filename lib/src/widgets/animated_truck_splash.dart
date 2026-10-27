import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AnimatedTruckSplash extends StatefulWidget {
  const AnimatedTruckSplash({super.key});

  @override
  State<AnimatedTruckSplash> createState() => _AnimatedTruckSplashState();
}

class _AnimatedTruckSplashState extends State<AnimatedTruckSplash>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _driveController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _driveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _fadeIn = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0, .82, curve: Curves.easeOutCubic),
    );
    _logoScale = Tween<double>(begin: .82, end: 1).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, .10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _driveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FCFA), Color(0xFFF1F7F4)],
          ),
        ),
        child: SafeArea(
          left: false,
          right: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final roadWidth = constraints.maxWidth;
              return Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildProfessionalLogo(),
                          const SizedBox(height: 20),
                          const Text(
                            'TRANSPORT ONE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.55,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Fleet moving. Business growing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.slate,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 38),
                          _buildRoadAnimation(roadWidth),
                          const SizedBox(height: 16),
                          _buildLoadingMessage(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalLogo() {
    return ScaleTransition(
      scale: _logoScale,
      child: AnimatedBuilder(
        animation: _driveController,
        builder: (context, child) {
          final pulse =
              .5 + .5 * math.sin(_driveController.value * math.pi * 2);
          return Container(
            width: 90,
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Color.lerp(
                    const Color(0x2266D69B), const Color(0x6666D69B), pulse)!,
              ),
            ),
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color:
                        AppColors.primary.withValues(alpha: .18 + pulse * .10),
                    blurRadius: 22 + pulse * 7,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 39,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoadAnimation(double roadWidth) {
    return SizedBox(
      width: roadWidth,
      height: 126,
      child: AnimatedBuilder(
        animation: _driveController,
        builder: (context, _) {
          final progress = _driveController.value;
          final truckLeft = progress * (roadWidth - 126);
          final edgeOpacity =
              (math.sin(progress * math.pi) * 1.5).clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                height: 70,
                child: CustomPaint(
                  painter: _RealRoadPainter(progress),
                ),
              ),
              // Road without static READY and LIVE labels
              Positioned(
                left: truckLeft,
                bottom: 42,
                child: Opacity(
                  opacity: edgeOpacity,
                  child: const _MovingTruck(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return AnimatedBuilder(
      animation: _driveController,
      builder: (context, _) {
        final activeDot = (_driveController.value * 3).floor().clamp(0, 2);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Preparing your live fleet workspace',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 7),
            for (var i = 0; i < 3; i++) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: i == activeDot ? 6 : 4,
                height: i == activeDot ? 6 : 4,
                decoration: BoxDecoration(
                  color: i == activeDot
                      ? AppColors.primary
                      : const Color(0xFFB8C7C0),
                  shape: BoxShape.circle,
                ),
              ),
              if (i < 2) const SizedBox(width: 3),
            ],
          ],
        );
      },
    );
  }
}

class _MovingTruck extends StatelessWidget {
  const _MovingTruck();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      height: 58,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 94,
              height: 7,
              decoration: BoxDecoration(
                color: const Color(0x4D10271F),
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [
                  BoxShadow(color: Color(0x3810271F), blurRadius: 9),
                ],
              ),
            ),
          ),
          Positioned.fill(
            bottom: 2,
            child: Image.asset(
              'assets/images/splash_truck.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_shipping_rounded,
                size: 45,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RealRoadPainter extends CustomPainter {
  const _RealRoadPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final road = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 8, size.width, 48),
      Radius.zero,
    );
    canvas.drawShadow(Path()..addRRect(road), const Color(0x551B332A), 8, true);

    final asphalt = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF747D78), Color(0xFF454D49), Color(0xFF626B66)],
      ).createShader(road.outerRect);
    canvas.drawRRect(road, asphalt);

    final edgePaint = Paint()
      ..color = const Color(0xFFF6F8F7)
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(8, 14), Offset(size.width - 8, 14), edgePaint);
    canvas.drawLine(const Offset(8, 50), Offset(size.width - 8, 50), edgePaint);

    final dashPaint = Paint()
      ..color = const Color(0xFFF7F9F8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dashWidth = 32.0;
    const gap = 24.0;
    const cycle = dashWidth + gap;
    canvas.save();
    canvas.clipRRect(road);
    for (double x = 18; x < size.width - 8; x += cycle) {
      canvas.drawLine(
        Offset(x, 32),
        Offset(math.min(x + dashWidth, size.width - 8), 32),
        dashPaint,
      );
    }
    canvas.restore();

    final texture = Paint()..color = const Color(0x17333D38);
    for (var i = 0; i < 36; i++) {
      final x = (i * 47.0) % size.width;
      final y = 18 + ((i * 19) % 28);
      canvas.drawCircle(Offset(x, y.toDouble()), .7, texture);
    }
  }

  @override
  bool shouldRepaint(covariant _RealRoadPainter oldDelegate) =>
      oldDelegate.progress != progress;
}


