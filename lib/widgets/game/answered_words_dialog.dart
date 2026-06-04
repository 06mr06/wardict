import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/answered_entry.dart';
import '../../providers/game_provider.dart';

class AnsweredWordsDialog extends StatefulWidget {
  final List<AnsweredEntry> answeredItems;

  const AnsweredWordsDialog({
    super.key,
    required this.answeredItems,
  });

  @override
  State<AnsweredWordsDialog> createState() => _AnsweredWordsDialogState();
}

class _AnsweredWordsDialogState extends State<AnsweredWordsDialog> {
  final Set<int> _selectedWords = {};
  bool _allSelected = false;

  @override
  void initState() {
    super.initState();
    // Initially select all words
    for (int i = 0; i < widget.answeredItems.length; i++) {
      _selectedWords.add(i);
    }
    _allSelected = widget.answeredItems.isNotEmpty;
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedWords.clear();
        _allSelected = false;
      } else {
        for (int i = 0; i < widget.answeredItems.length; i++) {
          _selectedWords.add(i);
        }
        _allSelected = true;
      }
    });
  }

  void _toggleWord(int index) {
    setState(() {
      if (_selectedWords.contains(index)) {
        _selectedWords.remove(index);
        _allSelected = false;
      } else {
        _selectedWords.add(index);
        if (_selectedWords.length == widget.answeredItems.length) {
          _allSelected = true;
        }
      }
    });
  }

  void _addToMyWords() {
    if (_selectedWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen en az bir kelime seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final gameProvider = context.read<GameProvider>();
    int addedCount = 0;

    for (final index in _selectedWords) {
      final entry = widget.answeredItems[index];
      // GameProvider addToPool metodunu kullan
      if (!gameProvider.isSaved(entry)) {
        gameProvider.addToPool(entry);
        addedCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('$addedCount kelime My Words\'e eklendi'),
            ],
          ),
          backgroundColor: const Color(0xFF2E5A8C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A5C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(128),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Çıkmış Kelimeler',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: widget.answeredItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = widget.answeredItems[index];
                  final isSelected = _selectedWords.contains(index);
                  final isCorrect = item.selectedIndex == item.correctIndex;

                  return GestureDetector(
                    onTap: () => _toggleWord(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withAlpha(26)
                            : Colors.white.withAlpha(13),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.amber.withAlpha(153)
                              : Colors.white12,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isCorrect ? Colors.green : Colors.red).withAlpha(51),
                              ),
                              child: Icon(
                                isCorrect ? Icons.check_rounded : Icons.close_rounded,
                                size: 18,
                                color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.correctText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.prompt + (item.turkishMeaning != null ? ' | ${item.turkishMeaning}' : ''),
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(153),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleWord(index),
                                activeColor: Colors.amber,
                                checkColor: Colors.black,
                                side: const BorderSide(color: Colors.white38),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _toggleSelectAll,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.amber,
                      ),
                      child: Text(
                        _allSelected ? 'Tümünü Kaldır' : 'Tümünü Seç',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _selectedWords.isNotEmpty ? _addToMyWords : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        shadowColor: Colors.amber.withAlpha(102),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.bookmark_add_rounded),
                      label: Text(
                        'Seçilenleri My Words\'e Ekle (${_selectedWords.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
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
