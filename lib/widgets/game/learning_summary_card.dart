import 'package:flutter/material.dart';
import '../../models/answered_entry.dart';

class LearningSummaryCard extends StatelessWidget {
  final List<AnsweredEntry> answerHistory;

  const LearningSummaryCard({
    super.key,
    required this.answerHistory,
  });

  @override
  Widget build(BuildContext context) {
    final wrongAnswers = answerHistory
        .where((e) => e.selectedIndex != e.correctIndex)
        .toList();

    if (wrongAnswers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  'Öğrenme Özeti',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Yanlış cevapladığın ${wrongAnswers.length} kelime öğrenme kuyruğuna (SRS) eklendi. Daha sonra tekrar karşına çıkacak.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 12),
            ...wrongAnswers.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.close, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.correctText,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (entry.turkishMeaning != null &&
                                entry.turkishMeaning!.isNotEmpty)
                              Text(
                                entry.turkishMeaning!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
