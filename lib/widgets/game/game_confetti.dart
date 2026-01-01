import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class GameConfetti extends StatefulWidget {
  final ConfettiController controller;
  final Alignment alignment;
  final List<Color>? colors;

  const GameConfetti({
    super.key,
    required this.controller,
    this.alignment = Alignment.center,
    this.colors,
  });

  @override
  State<GameConfetti> createState() => _GameConfettiState();
}

class _GameConfettiState extends State<GameConfetti> {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: ConfettiWidget(
        confettiController: widget.controller,
        blastDirectionality: BlastDirectionality.explosive, // radial
        shouldLoop: false,
        colors: widget.colors ?? const [
          Colors.green,
          Colors.blue,
          Colors.pink,
          Colors.orange,
          Colors.purple
        ], 
        createParticlePath: drawStar, // define a custom shape/path.
      ),
    );
  }

  /// A custom Path to paint stars.
  Path drawStar(Size size) {
    // Method to convert degree to radians
    double degToRad(double deg) => deg * (pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step),
          halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }
}
