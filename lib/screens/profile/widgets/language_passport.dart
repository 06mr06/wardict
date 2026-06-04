import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lugorena/models/user_level.dart';
import 'package:lugorena/providers/language_provider.dart';
import 'package:lugorena/services/word_category_service.dart';

class LanguagePassport extends StatelessWidget {
  final UserProfile profile;

  const LanguagePassport({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final stats = profile.categoryStats;
    
    // Kategoriler ve ikonları
    final categories = [
      {'id': 'verbs', 'icon': Icons.play_arrow_rounded, 'color': Colors.blue},
      {'id': 'nouns', 'icon': Icons.category_rounded, 'color': Colors.green},
      {'id': 'phrasals', 'icon': Icons.extension_rounded, 'color': Colors.orange},
      {'id': 'adjectives', 'icon': Icons.style_rounded, 'color': Colors.purple},
      {'id': 'adverbs', 'icon': Icons.speed_rounded, 'color': Colors.teal},
      {'id': 'idioms', 'icon': Icons.auto_awesome_rounded, 'color': Colors.amber},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(30), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Text(
                lang.getString('language_passport_title') ?? 'Dil Pasaportu',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lang.getString('language_passport_subtitle') ?? 'Öğrenme haritan ve uzmanlık alanların',
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ...categories.map((cat) {
            final id = cat['id'] as String;
            final catStat = stats[id] ?? {'correct': 0, 'wrong': 0};
            final correct = catStat['correct'] ?? 0;
            final wrong = catStat['wrong'] ?? 0;
            final total = correct + wrong;
            final successRate = total == 0 ? 0.0 : (correct / total);
            final color = cat['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withAlpha(40),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(cat['icon'] as IconData, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            WordCategoryService.instance.getCategoryName(id, lang.currentLanguage),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        total > 0 ? '%${(successRate * 100).toInt()}' : '-',
                        style: TextStyle(
                          color: total > 0 ? _getRateColor(successRate) : Colors.white.withAlpha(100),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 1000),
                        height: 8,
                        width: MediaQuery.of(context).size.width * 0.7 * (total > 0 ? successRate : 0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withAlpha(150), color],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: color.withAlpha(100),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$correct Doğru / $total Toplam',
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getRateColor(double rate) {
    if (rate >= 0.8) return Colors.greenAccent;
    if (rate >= 0.5) return Colors.amberAccent;
    return Colors.redAccent;
  }
}
