import 'dart:math' as math;
import 'package:flutter/material.dart';

/// J.A.R.V.I.S. Holographic HUD / Arc Reactor Widget
/// Pure Canvas CustomPainter with Multi-Tier Counter-Rotating Concentric Rings,
/// Segmented Dashed Arcs, Telemetry Tick Marks, Orbital Satellites, and Dynamic Pulse.
class JarvisHoloHud extends StatefulWidget {
  final double size;
  final Color accentColor;
  final IconData? centerIcon;
  final bool showShockwaves;

  const JarvisHoloHud({
    super.key,
    this.size = 110,
    this.accentColor = const Color(0xFF00E5FF),
    this.centerIcon,
    this.showShockwaves = true,
  });

  @override
  State<JarvisHoloHud> createState() => _JarvisHoloHudState();
}

class _JarvisHoloHudState extends State<JarvisHoloHud>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Smooth Continuous Rotation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // 2. Harmonic Sine Breathing Pulse & Shockwave
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: widget.accentColor, end: widget.accentColor),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, animatedColor, child) {
        final color = animatedColor ?? widget.accentColor;

        return AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _pulseController]),
          builder: (context, child) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Ambient Glow Aura
                  Container(
                    width: widget.size * 0.9,
                    height: widget.size * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(
                            alpha: 0.25 * _pulseAnimation.value.clamp(0.5, 1.0),
                          ),
                          blurRadius: widget.size * 0.35,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                  // Custom Canvas Holographic Geometry
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _JarvisHudPainter(
                      rotationProgress: _rotationController.value,
                      pulseScale: _pulseAnimation.value,
                      waveProgress: _waveAnimation.value,
                      accentColor: color,
                      showShockwaves: widget.showShockwaves,
                    ),
                  ),

                  // Central Centerpiece / Icon
                  if (widget.centerIcon != null)
                    Transform.scale(
                      scale: _pulseAnimation.value.clamp(0.9, 1.1),
                      child: Icon(
                        widget.centerIcon,
                        color: color,
                        size: widget.size * 0.30,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// CustomPainter that renders the futuristic telemetry HUD rings
class _JarvisHudPainter extends CustomPainter {
  final double rotationProgress;
  final double pulseScale;
  final double waveProgress;
  final Color accentColor;
  final bool showShockwaves;

  _JarvisHudPainter({
    required this.rotationProgress,
    required this.pulseScale,
    required this.waveProgress,
    required this.accentColor,
    required this.showShockwaves,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final primaryPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // ─────────────────────────────────────────────────────────────
    // Layer 0: Expanding Shockwave Ripple
    // ─────────────────────────────────────────────────────────────
    if (showShockwaves) {
      final rippleRadius = maxRadius * 0.45 + (maxRadius * 0.50 * waveProgress);
      final rippleAlpha = (1.0 - waveProgress).clamp(0.0, 1.0) * 0.45;
      final ripplePaint = Paint()
        ..color = accentColor.withValues(alpha: rippleAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, rippleRadius, ripplePaint);
    }

    // ─────────────────────────────────────────────────────────────
    // Layer 1: Outer Telemetry Ring with Tick Notches (Rotates Clockwise)
    // ─────────────────────────────────────────────────────────────
    final outerAngle = rotationProgress * 2 * math.pi;
    final rOuter = maxRadius * 0.94;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(outerAngle);

    // 4 Segmented Primary Arcs
    primaryPaint.strokeWidth = 1.6;
    const sweepAngleOuter = (math.pi / 2) - 0.30;
    for (int i = 0; i < 4; i++) {
      final startAngle = i * (math.pi / 2) + 0.15;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: rOuter),
        startAngle,
        sweepAngleOuter,
        false,
        primaryPaint..color = accentColor.withValues(alpha: 0.85),
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: rOuter),
        startAngle,
        sweepAngleOuter,
        false,
        glowPaint..strokeWidth = 3.5,
      );
    }

    // 16 Micro Telemetry Radial Tick Marks
    final tickPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 16; i++) {
      final angle = i * (2 * math.pi / 16);
      final isMajor = i % 4 == 0;
      final tickLength = isMajor ? 5.5 : 3.0;
      final p1 = Offset(math.cos(angle) * (rOuter - 1), math.sin(angle) * (rOuter - 1));
      final p2 = Offset(
        math.cos(angle) * (rOuter - 1 - tickLength),
        math.sin(angle) * (rOuter - 1 - tickLength),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    canvas.restore();

    // ─────────────────────────────────────────────────────────────
    // Layer 2: Middle Reticle Ring & Orbiting Satellites (Counter-Clockwise)
    // ─────────────────────────────────────────────────────────────
    final midAngle = -rotationProgress * 2 * math.pi * 1.5;
    final rMid = maxRadius * 0.74;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(midAngle);

    // 3 Heavy Targeting Brackets
    primaryPaint.strokeWidth = 2.2;
    const sweepAngleMid = (2 * math.pi / 3) - 0.50;
    for (int i = 0; i < 3; i++) {
      final startAngle = i * (2 * math.pi / 3) + 0.25;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: rMid),
        startAngle,
        sweepAngleMid,
        false,
        primaryPaint..color = accentColor.withValues(alpha: 0.95),
      );
    }

    // Orbiting Satellite Nodes
    final nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final nodeGlow = Paint()
      ..color = accentColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (int i = 0; i < 2; i++) {
      final angle = i * math.pi + 0.3;
      final nodePos = Offset(math.cos(angle) * rMid, math.sin(angle) * rMid);
      canvas.drawCircle(nodePos, 4.0, nodeGlow);
      canvas.drawCircle(nodePos, 2.2, nodePaint);
    }

    canvas.restore();

    // ─────────────────────────────────────────────────────────────
    // Layer 3: Inner Gear / Hex Iris (Fast Clockwise)
    // ─────────────────────────────────────────────────────────────
    final innerAngle = rotationProgress * 2 * math.pi * 2.2;
    final rInner = maxRadius * 0.52;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(innerAngle);

    final innerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 6-spoke crossbar ticks
    for (int i = 0; i < 6; i++) {
      final angle = i * (math.pi / 3);
      final p1 = Offset(math.cos(angle) * (rInner * 0.75), math.sin(angle) * (rInner * 0.75));
      final p2 = Offset(math.cos(angle) * rInner, math.sin(angle) * rInner);
      canvas.drawLine(p1, p2, innerPaint);
    }
    canvas.drawCircle(Offset.zero, rInner, innerPaint);

    canvas.restore();

    // ─────────────────────────────────────────────────────────────
    // Layer 4: Central Arc Reactor Glowing Core
    // ─────────────────────────────────────────────────────────────
    final coreRadius = maxRadius * 0.30 * pulseScale.clamp(0.85, 1.15);
    final coreGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: 0.9),
          accentColor.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius * 1.6));

    canvas.drawCircle(center, coreRadius * 1.6, coreGlowPaint);

    final solidCorePaint = Paint()
      ..color = const Color(0xFF0E1630)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coreRadius * 0.85, solidCorePaint);

    final coreBorderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, coreRadius * 0.85, coreBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _JarvisHudPainter oldDelegate) {
    return oldDelegate.rotationProgress != rotationProgress ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.waveProgress != waveProgress ||
        oldDelegate.accentColor != accentColor;
  }
}
