import 'package:flutter/material.dart';

/// Sallanma animasyonu widget'ı
/// Coin, joker gibi ikonları sallayarak dikkat çekmek için kullanılır
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double shakeOffset;
  final int shakeCount;

  const ShakeWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.shakeOffset = 10.0,
    this.shakeCount = 3,
  });

  /// GlobalKey ile animasyonu tetiklemek için kullanılır
  static void shake(GlobalKey<ShakeWidgetState> key) {
    key.currentState?.shake();
  }

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticIn,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sallanma animasyonunu başlat
  void shake() {
    _controller.forward().then((_) => _controller.reset());
  }

  double _getOffset(double animation) {
    // Sallanma pattern'i: sağ-sol-sağ-sol...
    final progress = animation * widget.shakeCount * 2;
    final sineValue = _sin(progress * 3.14159);
    return sineValue * widget.shakeOffset * (1 - animation);
  }

  double _sin(double radians) {
    // Basit sine yaklaşımı
    return radians - (radians * radians * radians) / 6;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_getOffset(_animation.value), 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Kullanım örneği:
/// 
/// final _coinShakeKey = GlobalKey<ShakeWidgetState>();
/// 
/// ShakeWidget(
///   key: _coinShakeKey,
///   child: Icon(Icons.monetization_on),
/// )
/// 
/// // Animasyonu tetiklemek için:
/// _coinShakeKey.currentState?.shake();
