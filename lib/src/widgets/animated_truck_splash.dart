import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedTruckSplash extends StatefulWidget {
  const AnimatedTruckSplash({super.key});

  @override
  State<AnimatedTruckSplash> createState() => _AnimatedTruckSplashState();
}

class _AnimatedTruckSplashState extends State<AnimatedTruckSplash>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _motion;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: .82, end: 1).animate(
      CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061E18),
      body: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-.15, -.25),
                  radius: 1.15,
                  colors: [
                    Color(0xFF0F513B),
                    Color(0xFF082D24),
                    Color(0xFF041712),
                  ],
                  stops: [0, .48, 1],
                ),
              ),
            ),
            CustomPaint(
              painter: _FleetBackgroundPainter(_motion.value),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: FadeTransition(
                        opacity: _fade,
                        child: ScaleTransition(
                          scale: _scale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLogo(),
                              const SizedBox(height: 22),
                              const Text(
                                'TRANSPORT ONE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.1,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'SMART FLEET  •  LIVE ROUTES  •  SAFE DELIVERY',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF9FE8C7),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.25,
                                ),
                              ),
                              const SizedBox(height: 28),
                              _buildRouteCard(),
                              const SizedBox(height: 18),
                              _buildStatusChips(),
                              const SizedBox(height: 24),
                              _buildLoading(),
                            ],
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
    );
  }

  Widget _buildLogo() {
    final pulse = .5 + .5 * math.sin(_motion.value * math.pi * 2);
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: _motion.value * math.pi * 2,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x5546E6A1), width: 1.4),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6EF0B5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0xAA6EF0B5), blurRadius: 9)
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 84 + pulse * 4,
            height: 84 + pulse * 4,
            decoration: BoxDecoration(
              color: const Color(0xFF10A85C),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: const Color(0x665FF0AC), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981)
                      .withValues(alpha: .25 + pulse * .18),
                  blurRadius: 28 + pulse * 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: Colors.white, size: 43),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: const Color(0xB30A2A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x335DE3A5)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final progress = Curves.easeInOutCubic.transform(_motion.value);
          const start = Offset(34, 116);
          final control = Offset(width * .48, 20);
          final end = Offset(width - 34, 62);
          final x = math.pow(1 - progress, 2) * start.dx +
              2 * (1 - progress) * progress * control.dx +
              math.pow(progress, 2) * end.dx;
          final y = math.pow(1 - progress, 2) * start.dy +
              2 * (1 - progress) * progress * control.dy +
              math.pow(progress, 2) * end.dy;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _RoutePainter(progress)),
              ),
              const Positioned(
                  left: 19,
                  bottom: 22,
                  child: _RoutePin(label: 'START', color: Color(0xFF34D399))),
              const Positioned(
                  right: 18,
                  top: 25,
                  child: _RoutePin(label: 'LIVE', color: Color(0xFFF97316))),
              Positioned(
                left: x.toDouble() - 21,
                top: y.toDouble() - 21,
                child: Transform.translate(
                  offset:
                      Offset(0, math.sin(_motion.value * math.pi * 12) * 1.3),
                  child: Container(
                    width: 43,
                    height: 43,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A867),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x9910B981),
                            blurRadius: 18,
                            spreadRadius: 2)
                      ],
                    ),
                    child: const Icon(Icons.local_shipping_rounded,
                        color: Colors.white, size: 23),
                  ),
                ),
              ),
              const Positioned(
                left: 18,
                top: 14,
                child: Row(
                  children: [
                    _LiveDot(),
                    SizedBox(width: 7),
                    Text('LIVE FLEET NETWORK',
                        style: TextStyle(
                            color: Color(0xFFB9F4D6),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusChips() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatusChip(icon: Icons.gps_fixed_rounded, label: 'LIVE GPS'),
        SizedBox(width: 8),
        _StatusChip(icon: Icons.alt_route_rounded, label: 'SMART ROUTES'),
        SizedBox(width: 8),
        _StatusChip(icon: Icons.verified_user_outlined, label: 'SECURE'),
      ],
    );
  }

  Widget _buildLoading() {
    final phase = (_motion.value * 3).floor() % 3;
    final message = switch (phase) {
      0 => 'Connecting live fleet...',
      1 => 'Syncing routes & drivers...',
      _ => 'Workspace ready to move...',
    };
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 4,
            color: const Color(0x3346E6A1),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: .22 + _motion.value * .78,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF8BF5C1)]),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            message,
            key: ValueKey(message),
            style: const TextStyle(
                color: Color(0xFFC4E8D8),
                fontSize: 11.5,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _FleetBackgroundPainter extends CustomPainter {
  const _FleetBackgroundPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x1027D17F)
      ..strokeWidth = 1;
    const gap = 42.0;
    final shift = progress * gap;
    for (double x = -gap + shift; x < size.width + gap; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = -gap + shift; y < size.height + gap; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final glow = Paint()..color = const Color(0x1824E192);
    for (var i = 0; i < 14; i++) {
      final x = (i * 89.0 + progress * 120) % size.width;
      final y = (i * 137.0 + progress * 65) % size.height;
      canvas.drawCircle(Offset(x, y), i.isEven ? 2.2 : 1.2, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _FleetBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(35, 116)
      ..quadraticBezierTo(size.width * .48, 20, size.width - 35, 62);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x302DE18B)
          ..strokeWidth = 12
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF6EE7B7)
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    final metric = path.computeMetrics().first;
    final active = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
        active,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RoutePin extends StatelessWidget {
  const _RoutePin({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)),
            child:
                const Icon(Icons.place_rounded, color: Colors.white, size: 15),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFB9F4D6),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7)),
        ],
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0x3346E6A1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF6EE7B7), size: 13),
              const SizedBox(width: 5),
              Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4))),
            ],
          ),
        ),
      );
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFF52F2A6),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0xAA52F2A6), blurRadius: 7)],
        ),
      );
}
