import 'package:flutter/material.dart';

/// Connection Lost Dialog - İnternet bağlantısı kesilince gösterilir
class ConnectionLostDialog extends StatelessWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onExit;
  final VoidCallback? onPractice;

  const ConnectionLostDialog({
    super.key,
    this.onRetry,
    this.onExit,
    this.onPractice,
  });

  /// Dialog'u göster
  static Future<void> show(BuildContext context, {
    VoidCallback? onRetry,
    VoidCallback? onExit,
    VoidCallback? onPractice,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConnectionLostDialog(
        onRetry: onRetry,
        onExit: onExit,
        onPractice: onPractice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withAlpha(128), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Connection Lost',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'İnternet bağlantınız kesildi.\nLütfen bağlantınızı kontrol edin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onExit?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Çıkış'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetry?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tekrar Dene'),
                    ),
                  ),
                ],
              ),
              
              // Practice Button (Offline Mode)
              if (onPractice != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onPractice?.call();
                    },
                    icon: const Icon(Icons.school, color: Colors.white),
                    label: const Text('Practice Modu (Çevrimdışı)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D9F5),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mixin for network-aware screens
mixin NetworkAwareMixin<T extends StatefulWidget> on State<T> {
  bool _isDialogShowing = false;

  void showConnectionLostDialog({
    VoidCallback? onRetry,
    VoidCallback? onExit,
    VoidCallback? onPractice,
  }) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;
    
    ConnectionLostDialog.show(
      context,
      onRetry: () {
        _isDialogShowing = false;
        onRetry?.call();
      },
      onExit: () {
        _isDialogShowing = false;
        if (onExit != null) {
          onExit();
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      onPractice: onPractice,
    );
  }
}
