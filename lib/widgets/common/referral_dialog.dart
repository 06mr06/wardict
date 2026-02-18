import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/referral_service.dart';
import 'package:share_plus/share_plus.dart';

class ReferralDialog extends StatefulWidget {
  const ReferralDialog({super.key});

  @override
  State<ReferralDialog> createState() => _ReferralDialogState();
}

class _ReferralDialogState extends State<ReferralDialog> {
  final TextEditingController _codeController = TextEditingController();
  String _myCode = '...';
  bool _hasUsedCode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final code = await ReferralService.instance.getMyReferralCode();
    final hasUsed = await ReferralService.instance.hasUsedReferral();
    if (mounted) {
      setState(() {
        _myCode = code;
        _hasUsedCode = hasUsed;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final result = await ReferralService.instance.useReferralCode(code);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.redAccent,
        ),
      );
      if (result['success']) {
        setState(() {
          _hasUsedCode = true;
          _codeController.clear();
        });
      }
    }
  }

  void _shareCode() {
    final text = 'WarDict kelime savaşında bana katıl! Benim davet kodum: $_myCode\n\nUygulamayı indir ve kodumu kullanarak 250 Altın kazan!';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ARKADAŞLARINI DAVET ET',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // My Code Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Text('Senin Davet Kodun', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _myCode,
                        style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _myCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kod kopyalandı!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _shareCode,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('KODU PAYLAŞ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C27FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 24),
            
            // Enter Code Section
            if (!_hasUsedCode) ...[
              const Text('Başkasının Kodunu Gir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Örn: WD1234',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2E5A8C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('KODU UYGULA', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kod uyguladığında 250 Altın kazanırsın!',
                style: TextStyle(color: Colors.greenAccent, fontSize: 11),
              ),
            ] else 
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Daha önce bir davet kodu kullandınız. Teşekkürler!',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('KAPAT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
