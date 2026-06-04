import 'package:flutter/material.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A5C), // Koyu mavi tema
      appBar: AppBar(
        title: const Text('Haberler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildNewsCard(
              'Yeni Sezon Başladı!',
              'Kış sezonu başladı. Yeni ödüller, ligler ve kelime paketleri seni bekliyor. Hemen oyna ve sıralamada yüksel!',
              '18.02.2026',
              Icons.ac_unit,
              Colors.cyan,
            ),
            _buildNewsCard(
              'Güncelleme Notları v1.2',
              'Performans iyileştirmeleri yapıldı. Artık düellolar daha akıcı. Ayrıca yeni "Daily 123" modu eklendi.',
              '15.02.2026',
              Icons.update,
              Colors.green,
            ),
             _buildNewsCard(
              'Topluluk Etkinliği',
              'Bu hafta sonu tüm oyunlarda %50 daha fazla XP ve Altın kazanma şansı! Arkadaşlarını davet etmeyi unutma.',
              '10.02.2026',
              Icons.people,
              Colors.orange,
            ),
            _buildNewsCard(
              'Premium İndirimi',
              'Kısa bir süre için Yıllık Premium üyelikte %30 indirim fırsatı. Reklamsız deneyim ve sınırsız can için kaçırma.',
              '05.02.2026',
              Icons.star,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(String title, String description, String date, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withAlpha(204),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.white.withAlpha(102)),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: TextStyle(
                          color: Colors.white.withAlpha(102),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
