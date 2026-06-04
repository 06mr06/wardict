import 'package:flutter/material.dart';
import 'dart:ui';

class TopToast extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const TopToast({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.check_circle_rounded,
    this.color = const Color(0xFF6C27FF),
  });

  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color color = const Color(0xFF6C27FF),
  }) {
    if (!context.mounted) return;

    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.maybeOf(context) ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;

    void dismissEntry() {
      try {
        entry.remove();
      } catch (_) {}
      if (identical(_activeEntry, entry)) _activeEntry = null;
    }

    entry = OverlayEntry(
      builder: (context) => _WardictPopupWidget(
        title: title,
        message: message,
        icon: icon,
        color: color,
        onDismiss: dismissEntry,
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _WardictPopupWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _WardictPopupWidget({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.onDismiss,
  });

  @override
  State<_WardictPopupWidget> createState() => _WardictPopupWidgetState();
}

class _WardictPopupWidgetState extends State<_WardictPopupWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _blurAnimation = Tween<double>(begin: 0.0, end: 5.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _controller.forward();

    Future.delayed(const Duration(seconds: 2, milliseconds: 500), () async {
      try {
        if (mounted) await _controller.reverse();
      } catch (_) {
        // Controller zaten dispose edilmiş olabilir
      }
      widget.onDismiss();
    });
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
        return Stack(
          children: [
            // Backdrop Blur
            if (_blurAnimation.value > 0.1)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: _blurAnimation.value, sigmaY: _blurAnimation.value),
                child: Container(color: Colors.black.withAlpha((_opacityAnimation.value * 128).toInt())),
              ),
            
            // Pop-up Card
            Center(
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color.withAlpha(50),
                            Colors.black.withAlpha(230),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: widget.color.withAlpha(180), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withAlpha(100),
                            blurRadius: 40,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glowing Icon
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: widget.color.withAlpha(40),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color.withAlpha(60),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(widget.icon, color: widget.color, size: 48),
                          ),
                          const SizedBox(height: 24),
                          // Title
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Message
                          Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
