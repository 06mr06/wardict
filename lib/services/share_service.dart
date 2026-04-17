import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:share_plus/share_plus.dart';

import 'referral_service.dart';

/// Skor kartÄ± paylaÅŸÄ±mÄ± â€” sosyal viralite.
///
/// SonuÃ§ ekranÄ±ndaki bir `RepaintBoundary`'nin PNG snapshot'Ä±nÄ± alÄ±r ve
/// kullanÄ±cÄ±nÄ±n davet koduyla birlikte `share_plus` Ã¼zerinden paylaÅŸÄ±r.
class ShareService {
  static final ShareService instance = ShareService._();
  ShareService._();

  /// [boundaryKey] paylaÅŸÄ±lacak widget'Ä± saran `RepaintBoundary`'nin key'i.
  Future<void> shareScoreCard({
    required GlobalKey boundaryKey,
    required String headline,
    String? customMessage,
  }) async {
    try {
      if (kIsWeb) {
        await _shareTextFallback(headline, customMessage);
        return;
      }
      final bytes = await _captureBoundary(boundaryKey);
      if (bytes == null) {
        await _shareTextFallback(headline, customMessage);
        return;
      }
      final tmp = await pp.getTemporaryDirectory();
      final file = File('${tmp.path}/lugorena_score.png');
      await file.writeAsBytes(bytes, flush: true);

      final referral = await ReferralService.instance.getMyReferralCode();
      final msg = customMessage ??
          '$headline\n\n'
              'LUGORENA ile Ä°ngilizce kelimeleri oynayarak Ã¶ÄŸren!\n'
              'Davet kodum: $referral â†’ ilk giriÅŸinde 250 altÄ±n hediye ðŸŽ';

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: msg,
        subject: 'LUGORENA skorum',
      );
    } catch (e) {
      debugPrint('âš ï¸ shareScoreCard error: $e');
      await _shareTextFallback(headline, customMessage);
    }
  }

  /// Uyumluluk için eklenmiş olan metot - Aslında shareScoreCard ile aynı işlemi yapar
  Future<void> shareWidgetAsImage(GlobalKey boundaryKey, String message) async {
    await shareScoreCard(boundaryKey: boundaryKey, headline: message, customMessage: message);
  }

  Future<Uint8List?> _captureBoundary(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;
    final ui.Image image = await ro.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareTextFallback(
    String headline,
    String? customMessage,
  ) async {
    final referral = await ReferralService.instance.getMyReferralCode();
    final msg = customMessage ??
        '$headline â€” LUGORENA\'da Ä°ngilizce Ã¶ÄŸreniyorum. '
            'Davet kodum: $referral â†’ 250 altÄ±n hediye!';
    await Share.share(msg, subject: 'LUGORENA');
  }
}
