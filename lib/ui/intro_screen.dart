import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Kurzes Intro nach dem Start: Ring zeichnet sich, darunter Name und
/// Leitsatz (Vorlage: assets/branding/startbildschirm_vorlage.png).
/// Tippen überspringt; bei „Bewegung reduzieren“ steht der Ring sofort.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  static const duration = Duration(milliseconds: 1800);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: IntroScreen.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _finish();
        });

  late final Animation<double> _ring = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _text = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
  );

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _controller.stop();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Scaffold(
        backgroundColor: RitualColors.background,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final textOpacity = reduceMotion ? 1.0 : _text.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RitualLogo(
                    size: 132,
                    progress: reduceMotion ? 1.0 : _ring.value,
                  ),
                  const SizedBox(height: 56),
                  Opacity(
                    opacity: textOpacity,
                    child: Column(
                      children: [
                        Text(
                          'RITUAL',
                          style: text.displaySmall?.copyWith(
                            color: RitualColors.cream,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 16,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                            width: 40, height: 1, color: RitualColors.gold),
                        const SizedBox(height: 28),
                        for (final line in const [
                          'Sacrifice the moment.',
                          'Evolve the future.',
                        ])
                          Text(
                            line,
                            style: text.headlineSmall?.copyWith(
                              color: RitualColors.gold,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w400,
                              height: 1.35,
                            ),
                          ),
                      ],
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

/// Logo „R im Ring“: goldener Bogen mit Punkt am Ende, Rest der Bahn dunkel.
/// [progress] 0..1 zeichnet den Bogen (1 = wie im App-Icon).
class RitualLogo extends StatelessWidget {
  const RitualLogo({super.key, this.size = 96, this.progress = 1});

  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ritual',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(progress: progress),
          child: Center(
            child: Text(
              'R',
              style: TextStyle(
                fontFamily: ritualSerif,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w500,
                color: RitualColors.gold,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  /// Der goldene Bogen endet wie in der Vorlage bei ca. 10:30 Uhr.
  static const _fullSweep = 2 * math.pi * 7 / 8;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.025;
    final radius = size.width / 2 - stroke * 2.2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = RitualColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);

    final sweep = _fullSweep * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    const start = -math.pi / 2;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = RitualColors.gold
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
    final end = start + sweep;
    canvas.drawCircle(
      center + Offset(math.cos(end), math.sin(end)) * radius,
      stroke * 2.1,
      Paint()..color = RitualColors.gold,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
