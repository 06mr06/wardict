import 'package:flutter/material.dart';
import '../../../models/user_level.dart';
import '../../../models/online_duel.dart';
import '../../../models/cosmetic_item.dart';

class WelcomeTopBar extends StatelessWidget {
  final UserProfile? userProfile;
  final int coins;
  final OnlineDuelMatch? resumableDuel;
  final int pendingInvitationsCount;
  final String? selectedFrameId;
  final VoidCallback onProfileTap;
  final VoidCallback onQuestTap;
  final VoidCallback onNotificationTap;
  final AnimationController pulseController;

  final bool hasClaimableQuests;
  final bool allQuestsDone;

  const WelcomeTopBar({
    super.key,
    required this.userProfile,
    required this.coins,
    required this.resumableDuel,
    required this.pendingInvitationsCount,
    required this.selectedFrameId,
    required this.onProfileTap,
    required this.onQuestTap,
    required this.onNotificationTap,
    required this.pulseController,
    this.hasClaimableQuests = false,
    this.allQuestsDone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Sol: Profil ve Kullanıcı Adı
        Flexible(
          child: GestureDetector(
            onTap: onProfileTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAvatarWithFrame(),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      userProfile?.username ?? 'USER',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Orta: Günlük Görevler & Bildirim / Zil
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDailyQuestIcon(),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onNotificationTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 28),
                  ),
                  if (resumableDuel != null || pendingInvitationsCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: resumableDuel != null ? Colors.blue : Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF030712), width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        
        // Sağ: Coin ve Chest
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                '$coins',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(width: 4),
              const Text('G', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  static const double _avatarSize = 40;

  Widget _buildAvatarWithFrame() {
    Color? frameColor;
    double frameBorderWidth = 0;
    bool isGradientFrame = false;

    if (selectedFrameId != null && selectedFrameId!.isNotEmpty) {
      final frames = CosmeticItem.availableItems.where((i) => i.id == selectedFrameId);
      if (frames.isNotEmpty) {
        final frame = frames.first;
        if (frame.previewValue == 'gradient') {
          isGradientFrame = true;
          frameBorderWidth = frame.borderWidth.toDouble();
        } else {
          try {
            final hexValue = frame.previewValue.replaceAll('#', '');
            if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hexValue)) {
              frameColor = Color(int.parse('FF$hexValue', radix: 16));
            }
          } catch (_) {}
          frameBorderWidth = frame.borderWidth.toDouble();
        }
      }
    }

    final fill = SizedBox(
      width: _avatarSize,
      height: _avatarSize,
      child: ClipOval(
        clipBehavior: Clip.antiAlias,
        child: SizedBox.expand(
          child: _buildAvatarContent(),
        ),
      ),
    );

    if (isGradientFrame && frameBorderWidth > 0) {
      return SizedBox(
        width: _avatarSize,
        height: _avatarSize,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFFFF0044),
                Color(0xFFFF8C00),
                Color(0xFFFFD600),
                Color(0xFF00E676),
                Color(0xFF00B0FF),
                Color(0xFF7C4DFF),
                Color(0xFFFF0044),
              ],
            ),
          ),
          padding: EdgeInsets.all(frameBorderWidth),
          child: ClipOval(
            child: SizedBox.expand(
              child: _buildAvatarContent(),
            ),
          ),
        ),
      );
    }

    if (frameColor != null && frameBorderWidth > 0) {
      return SizedBox(
        width: _avatarSize,
        height: _avatarSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            fill,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: frameColor, width: frameBorderWidth),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return fill;
  }

  Widget _buildAvatarContent() {
    if (userProfile?.profileImagePath != null && userProfile!.profileImagePath!.isNotEmpty) {
      final path = userProfile!.profileImagePath!;
      if (path.startsWith('assets/') || path.contains('assets/')) {
        return Image.asset(
          path,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 20, color: Colors.white),
        );
      }
      return Image.network(
        path,
        key: ValueKey(path),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 20, color: Colors.white),
      );
    }

    if (userProfile?.avatarId != null && userProfile!.avatarId!.isNotEmpty) {
      final items = CosmeticItem.availableItems.where((i) => i.id == userProfile!.avatarId);
      if (items.isNotEmpty) {
        final previewValue = items.first.previewValue;
        if (previewValue.startsWith('assets/') || previewValue.contains('assets/')) {
          return Image.asset(
            previewValue,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 20, color: Colors.white),
          );
        }
        return Center(
          child: Text(previewValue, style: const TextStyle(fontSize: 18)),
        );
      }
    }

    return ColoredBox(
      color: const Color(0xFF2E5A8C),
      child: Center(
        child: Text(
          (userProfile?.username.isNotEmpty == true)
              ? userProfile!.username[0].toUpperCase()
              : 'P',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildDailyQuestIcon() {
    Color borderColor;
    if (hasClaimableQuests) {
      borderColor = Colors.amber;
    } else if (allQuestsDone) {
      borderColor = Colors.green;
    } else {
      borderColor = const Color(0xFFFF5252);
    }

    return GestureDetector(
      onTap: onQuestTap,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          final pulseValue = hasClaimableQuests ? pulseController.value : 0.0;
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor.withValues(alpha: 0.4 + (0.6 * pulseValue)),
                width: 2.0 + (hasClaimableQuests ? 1.0 * pulseValue : 0.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.2 + (0.4 * pulseValue)),
                  blurRadius: 10 + (hasClaimableQuests ? 10 * pulseValue : 0),
                  spreadRadius: 1 + (hasClaimableQuests ? 2 * pulseValue : 0),
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.assignment_rounded, 
                  color: borderColor.withValues(alpha: 0.9), 
                  size: 24
                ),
                if (hasClaimableQuests)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.amber, blurRadius: 4)],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    }
}
