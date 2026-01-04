import 'package:flutter/material.dart';

/// Connection Lost Dialog - İnternet bağlantısı kesilince gösterilir
class ConnectionLostDialog extends StatelessWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onExit;

  const ConnectionLostDialog({
    super.key,
    this.onRetry,
    this.onExit,
  });

  /// Dialog'u göster
  static Future<void> show(BuildContext context, {
    VoidCallback? onRetry,
    VoidCallback? onExit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConnectionLostDialog(
        onRetry: onRetry,
        onExit: onExit,
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
            border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
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
                  color: Colors.white.withOpacity(0.8),
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
    );
  }
}
