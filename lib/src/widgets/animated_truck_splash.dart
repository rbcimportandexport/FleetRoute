import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AnimatedTruckSplash extends StatefulWidget {
  const AnimatedTruckSplash({super.key});

  @override
  State<AnimatedTruckSplash> createState() => _AnimatedTruckSplashState();
}

class _AnimatedTruckSplashState extends State<AnimatedTruckSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final roadWidth = math.min(constraints.maxWidth - 40, 430.0);
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3310B981),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'TRANSPORT ONE',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Fleet moving. Business growing.',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 42),
                  SizedBox(
                    width: roadWidth,
                    height: 82,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final progress = Curves.easeInOut.transform(
                          _controller.value,
                        );
                        final truckLeft = progress * (roadWidth - 58);
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 16,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            ...List.generate(6, (index) {
                              final segmentWidth = roadWidth / 8;
                              final offset =
                                  ((_controller.value * segmentWidth * 2) +
                                          index * segmentWidth * 1.6) %
                                      roadWidth;
                              return Positioned(
                                left: offset,
                                bottom: 18,
                                child: Container(
                                  width: segmentWidth * .72,
                                  height: 2,
                                  color: Colors.white,
                                ),
                              );
                            }),
                            Positioned(
                              left: truckLeft,
                              bottom: 22,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  math.sin(_controller.value * math.pi * 8) *
                                      1.5,
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  size: 52,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Preparing your live fleet workspace…',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
