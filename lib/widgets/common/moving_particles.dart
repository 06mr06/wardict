import 'dart:math';
import 'package:flutter/material.dart';

class MovingParticles extends StatefulWidget {
  final int count;
  final Color color;

  const MovingParticles({
    super.key,
    this.count = 20,
    this.color = Colors.white,
  });

  @override
  State<MovingParticles> createState() => _MovingParticlesState();
}

class _MovingParticlesState extends State<MovingParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    for (int i = 0; i < widget.count; i++) {
      _particles.add(Particle(
        position: Offset(_random.nextDouble(), _random.nextDouble()),
        size: _random.nextDouble() * 3 + 1,
        speed: _random.nextDouble() * 0.02 + 0.01,
        angle: _random.nextDouble() * pi * 2,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        for (var p in _particles) {
          p.update();
        }
        return CustomPaint(
          painter: ParticlePainter(_particles, widget.color),
          size: Size.infinite,
        );
      },
    );
  }
}

class Particle {
  Offset position;
  final double size;
  final double speed;
  double angle;

  Particle({
    required this.position,
    required this.size,
    required this.speed,
    required this.angle,
  });

  void update() {
    position = Offset(
      (position.dx + cos(angle) * speed / 100) % 1.0,
      (position.dy + sin(angle) * speed / 100) % 1.0,
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color color;

  ParticlePainter(this.particles, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.3);
    for (var p in particles) {
      canvas.drawCircle(
        Offset(p.position.dx * size.width, p.position.dy * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
