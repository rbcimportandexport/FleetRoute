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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final roadWidth = math.min(constraints.maxWidth - 40, 430.0);
              return Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
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
      height: 96,
      child: AnimatedBuilder(
        animation: _driveController,
        builder: (context, _) {
          final progress = _driveController.value;
          final truckLeft = progress * (roadWidth - 54);
          final edgeOpacity =
              (math.sin(progress * math.pi) * 1.5).clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 8,
                right: 8,
                bottom: 21,
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2EAE6),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x120F3D2F),
                          blurRadius: 8,
                          offset: Offset(0, 4)),
                    ],
                  ),
                ),
              ),
              ...List.generate(7, (index) {
                final segmentWidth = roadWidth / 9;
                final offset = ((progress * segmentWidth * 3) +
                        index * segmentWidth * 1.45) %
                    roadWidth;
                return Positioned(
                  left: offset,
                  bottom: 24.5,
                  child: Container(
                    width: segmentWidth * .62,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                );
              }),
              const Positioned(
                left: 1,
                bottom: 11,
                child:
                    _RoadPoint(icon: Icons.trip_origin_rounded, label: 'READY'),
              ),
              const Positioned(
                right: 0,
                bottom: 11,
                child:
                    _RoadPoint(icon: Icons.location_on_rounded, label: 'LIVE'),
              ),
              Positioned(
                left: truckLeft,
                bottom: 31,
                child: Opacity(
                  opacity: edgeOpacity,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      math.sin(progress * math.pi * 14) * 1.1,
                    ),
                    child: const _MovingTruck(),
                  ),
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
    return Container(
      width: 50,
      height: 42,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(13)),
        boxShadow: [
          BoxShadow(
              color: Color(0x2910B981), blurRadius: 13, offset: Offset(0, 6)),
        ],
      ),
      child: const Icon(Icons.local_shipping_rounded,
          size: 32, color: AppColors.primary),
    );
  }
}

class _RoadPoint extends StatelessWidget {
  const _RoadPoint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(icon, size: 13, color: AppColors.primary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.slate,
            fontSize: 7,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
      ],
    );
  }
}
