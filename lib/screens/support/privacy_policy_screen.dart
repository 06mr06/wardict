import 'package:flutter/material.dart';

/// Gizlilik Politikası Ekranı
/// Play Store yayını için zorunlu
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A5C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E5A8C),
        title: const Text('Gizlilik Politikası'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Gizlilik Politikası',
              'Son güncelleme: 3 Ocak 2026',
              isTitle: true,
            ),
            const SizedBox(height: 20),
            _buildSection(
              '1. Toplanan Bilgiler',
              '''WARDICT uygulaması aşağıdaki bilgileri toplar:

• Hesap Bilgileri: E-posta adresi, kullanıcı adı (Google ile giriş yapıldığında)
• Oyun Verileri: Skor, seviye, başarılar, kelime havuzu
• Cihaz Bilgileri: Cihaz türü, işletim sistemi (hata raporlama için)

Anonim (misafir) olarak oynarsanız, veriler yalnızca cihazınızda saklanır.''',
            ),
            _buildSection(
              '2. Verilerin Kullanımı',
              '''Toplanan veriler şu amaçlarla kullanılır:

• Oyun deneyimini kişiselleştirmek
• İlerlemenizi kaydetmek ve cihazlar arası senkronize etmek
• Liderlik tabloları ve arkadaş sistemi
• Uygulama performansını iyileştirmek
• Hata ve çökme raporları''',
            ),
            _buildSection(
              '3. Veri Paylaşımı',
              '''Kişisel verileriniz üçüncü taraflarla satılmaz veya paylaşılmaz.

Aşağıdaki hizmet sağlayıcılar kullanılmaktadır:
• Firebase (Google): Kimlik doğrulama ve veri depolama
• Google AdMob: Reklam gösterimi (reklamsız sürümde devre dışı)
• Google Play: Uygulama içi satın almalar''',
            ),
            _buildSection(
              '4. Reklam ve İzleme',
              '''Uygulama, Google AdMob aracılığıyla reklam gösterir.

AdMob, ilgi alanlarınıza göre reklamlar göstermek için reklam kimliği kullanabilir. 
"Reklamları Kaldır" satın alımı yaparak tüm reklamları devre dışı bırakabilirsiniz.

Cihaz ayarlarınızdan kişiselleştirilmiş reklamları kapatabilirsiniz.''',
            ),
            _buildSection(
              '5. Veri Güvenliği',
              '''Verileriniz Firebase altyapısı ile güvenli bir şekilde saklanır:

• HTTPS şifreleme ile veri aktarımı
• Firebase güvenlik kuralları ile erişim kontrolü
• Google Cloud altyapısı ile endüstri standardı güvenlik''',
            ),
            _buildSection(
              '6. Çocukların Gizliliği',
              '''WARDICT, 13 yaş ve üzeri kullanıcılar için tasarlanmıştır.

13 yaşından küçük çocuklardan bilerek kişisel bilgi toplamayız. Eğer çocuğunuzun bilgi paylaştığını düşünüyorsanız, lütfen bizimle iletişime geçin.''',
            ),
            _buildSection(
              '7. Kullanıcı Hakları',
              '''Aşağıdaki haklara sahipsiniz:

• Hesabınızı ve tüm verilerinizi silme
• Verilerinizin bir kopyasını talep etme
• Kişiselleştirilmiş reklamları reddetme

Bu hakları kullanmak için uygulama içi destek bölümünden bize ulaşabilirsiniz.''',
            ),
            _buildSection(
              '8. Değişiklikler',
              '''Bu gizlilik politikası zaman zaman güncellenebilir.

Önemli değişiklikler uygulama içinde bildirilecektir. Uygulamayı kullanmaya devam etmeniz, güncellenmiş politikayı kabul ettiğiniz anlamına gelir.''',
            ),
            _buildSection(
              '9. İletişim',
              '''Sorularınız için bize ulaşın:

📧 E-posta: support@wardict.app
🌐 Web: https://wardict.app''',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© 2026 WARDICT. Tüm hakları saklıdır.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, {bool isTitle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTitle ? 24 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
