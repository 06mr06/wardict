import 'package:flutter/material.dart';

class MenuCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLocked;
  final VoidCallback? onInfoTap;
  final double? progress;
  final String? progressLabel;
  final String? levelLabel;
  final String? levelSubLabel;

  const MenuCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLocked = false,
    this.onInfoTap,
    this.progress,
    this.progressLabel,
    this.levelLabel,
    this.levelSubLabel,
  });

  @override
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard> {
  bool _pressed = false;

  bool get _hasImage => widget.icon.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLocked) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                offset: const Offset(0, 10),
                blurRadius: 26,
                spreadRadius: -2,
              ),
              BoxShadow(
                color: (widget.isLocked ? Colors.black : widget.color).withValues(alpha: 0.30),
                offset: const Offset(0, 8),
                blurRadius: 28,
                spreadRadius: -10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildGradientLayer(),
                if (!widget.isLocked && _hasImage) _buildImageLayer(),
                _buildDarkOverlay(),
                _buildGlossyHighlight(),
                _buildInnerGlow(radius),
                _buildContent(),
                if (widget.isLocked) _buildLockOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientLayer() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isLocked
              ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
              : [
                  Color.alphaBlend(Colors.white.withValues(alpha: 0.12), widget.color),
                  widget.color,
                ],
        ),
      ),
    );
  }

  Widget _buildImageLayer() {
    return Positioned.fill(
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          1.14, 0, 0, 0, 8,
          0, 1.14, 0, 0, 8,
          0, 0, 1.14, 0, 8,
          0, 0, 0, 1, 0,
        ]),
        child: Image.asset(
          widget.icon,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }

  Widget _buildDarkOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withValues(alpha: 0.06),
              Colors.black.withValues(alpha: 0.50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlossyHighlight() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: 52,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.24),
                Colors.white.withValues(alpha: 0.04),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInnerGlow(BorderRadius radius) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
              width: 1,
            ),
            borderRadius: radius,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    height: 1.15,
                    shadows: [
                      Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12.5,
                    height: 1.3,
                    shadows: const [
                      Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 4),
                    ],
                  ),
                ),
                if (widget.levelLabel != null || widget.progress != null)
                  const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.levelLabel != null) _buildLevelChip(),
                    if (widget.levelLabel != null && widget.progress != null)
                      const SizedBox(width: 10),
                    if (widget.progress != null)
                      Expanded(child: _buildProgressBar()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (widget.onInfoTap != null && !widget.isLocked) _buildInfoButton(),
        ],
      ),
    );
  }

  Widget _buildLevelChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF4ADE80),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4ADE80).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.levelLabel!,
        style: const TextStyle(
          color: Color(0xFF0A2E1A),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildInfoButton() {
    return GestureDetector(
      onTap: widget.onInfoTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 18),
      ),
    );
  }

  Widget _buildLockOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55)),
        child: const Center(
          child: Icon(Icons.lock_rounded, color: Colors.white54, size: 38),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final p = (widget.progress ?? 0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: p,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.9),
                    widget.color.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
        if (widget.progressLabel != null) ...[
          const SizedBox(height: 3),
          Text(
            widget.progressLabel!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}