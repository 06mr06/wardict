import 'package:flutter/material.dart';

/// Kullanım Şartları Ekranı
/// Play Store yayını için önerilen
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A5C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E5A8C),
        title: const Text('Kullanım Şartları'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Kullanım Şartları',
              'Son güncelleme: 3 Ocak 2026',
              isTitle: true,
            ),
            const SizedBox(height: 20),
            _buildSection(
              '1. Kabul',
              '''LUGORENA uygulamasını kullanarak bu kullanım şartlarını kabul etmiş olursunuz.

Bu şartları kabul etmiyorsanız, lütfen uygulamayı kullanmayın.''',
            ),
            _buildSection(
              '2. Hizmet Açıklaması',
              '''LUGORENA, İngilizce kelime öğrenmeyi eğlenceli hale getiren bir mobil oyundur.

Uygulama şunları içerir:
• Kelime öğrenme oyunları
• Düello modu (bot ve çevrimiçi)
• Günlük görevler ve başarılar
• Liderlik tabloları
• Premium özellikler (opsiyonel satın alma)''',
            ),
            _buildSection(
              '3. Hesap ve Kayıt',
              '''Uygulamayı kullanmak için:

• Misafir olarak oynayabilirsiniz (veriler yalnızca cihazda kalır)
• Google hesabınızla giriş yapabilirsiniz
• E-posta ile kayıt olabilirsiniz

Hesap bilgilerinizin güvenliğinden siz sorumlusunuz.''',
            ),
            _buildSection(
              '4. Kullanıcı Davranışı',
              '''Aşağıdaki davranışlar yasaktır:

• Hakaret, küfür veya uygunsuz kullanıcı adları
• Hile, bot veya otomatik programlar kullanmak
• Diğer kullanıcıları taciz etmek
• Uygulamayı kötüye kullanmak veya güvenliğini tehlikeye atmak

Bu kurallara uymayan hesaplar askıya alınabilir veya silinebilir.''',
            ),
            _buildSection(
              '5. Sanal Para ve Satın Almalar',
              '''Uygulamada kullanılan "Altın" sanal bir para birimidir:

• Altın, gerçek parayla satın alınabilir
• Oyun içi etkinliklerle kazanılabilir
• Powerup ve kozmetik ürünler satın almak için kullanılır
• Gerçek paraya çevrilemez veya iade edilemez

Tüm satın almalar Google Play veya App Store üzerinden işlenir.''',
            ),
            _buildSection(
              '6. Premium Üyelik',
              '''Premium üyelik şunları sağlar:

• Reklamsız deneyim
• Özel powerup'lar
• Tüm oyun modlarına erişim

Abonelikler otomatik yenilenir. İptal etmek için cihaz ayarlarınızdan abonelik yönetimine gidin.''',
            ),
            _buildSection(
              '7. Fikri Mülkiyet',
              '''LUGORENA ve tüm içeriği telif hakkı ile korunmaktadır.

• Uygulama tasarımı, grafikleri ve kodu bize aittir
• Kullanıcı tarafından oluşturulan içerik (kullanıcı adı vb.) kullanıcıya aittir
• Uygulamayı kopyalamak, değiştirmek veya dağıtmak yasaktır''',
            ),
            _buildSection(
              '8. Sorumluluk Reddi',
              '''LUGORENA "olduğu gibi" sunulmaktadır.

• Hizmetin kesintisiz çalışacağını garanti etmiyoruz
• Sunucu bakımları için geçici kesintiler olabilir
• Oyun dengesini değiştirme hakkımız saklıdır

Teknik sorunlardan kaynaklanan veri kayıplarından sorumlu değiliz.''',
            ),
            _buildSection(
              '9. Değişiklikler',
              '''Bu şartları dilediğimiz zaman değiştirme hakkımız saklıdır.

Önemli değişiklikler uygulama içinde bildirilecektir. Değişikliklerden sonra uygulamayı kullanmaya devam etmeniz, yeni şartları kabul ettiğiniz anlamına gelir.''',
            ),
            _buildSection(
              '10. İletişim',
              '''Sorularınız için bize ulaşın:

📧 E-posta: support@wardict.app
🌐 Web: https://wardict.app''',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© 2026 LUGORENA. Tüm hakları saklıdır.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
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
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
