import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/answered_entry.dart';
import '../../models/question_mode.dart';

class MyWordsScreen extends StatefulWidget {
  const MyWordsScreen({super.key});

  @override
  State<MyWordsScreen> createState() => _MyWordsScreenState();
}

class _MyWordsScreenState extends State<MyWordsScreen> {
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;
  
  // Note: We need to load saved words. 
  // GameProvider has 'savedPool' but it might be session based?
  // We should rely on WordPoolService, but GameProvider wraps it.
  // Assuming GameProvider loads savedPool on init or we might need to trigger load.
  
  @override
  Widget build(BuildContext context) {
    // Access savedWords from provider
    // If GameProvider doesn't expose full saved list generically, we might need to add a getter.
    // For now, assuming gp.savedPool is the list. 
    // BUT gp.savedPool might be empty if we haven't played? 
    // We should populate it.
    
    final gp = context.watch<GameProvider>();
    final items = gp.savedPool; 
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelimelerim'),
        actions: [
          if (items.isNotEmpty)
             TextButton(
               onPressed: () => _toggleSelectAll(items.length),
               child: Text(
                 _selectedIndices.length == items.length ? 'Tümünü Kaldır' : 'Tümünü Seç', 
                 style: const TextStyle(fontWeight: FontWeight.bold)
               )
             )
        ],
      ),
      body: items.isEmpty 
        ? const Center(child: Text('Henüz kaydedilmiş kelime yok.'))
        : ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = _selectedIndices.contains(index);
              
              return ListTile(
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (v) => _toggleItem(index),
                ),
                title: Text(item.prompt),
                subtitle: Text(item.correctText),
                trailing: Text(item.mode.name),
                onTap: () => _toggleItem(index),
              );
            },
        ),
      floatingActionButton: _selectedIndices.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                 // Delete logic
                 _deleteSelected(gp);
              },
              label: Text('Sil (${_selectedIndices.length})'),
              icon: const Icon(Icons.delete),
              backgroundColor: Colors.red,
            )
          : null,
    );
  }

  void _toggleItem(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _toggleSelectAll(int count) {
    setState(() {
      if (_selectedIndices.length == count) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(List.generate(count, (i) => i));
      }
    });
  }

  void _deleteSelected(GameProvider gp) {
    final list = gp.savedPool; // Copy reference
    final toRemove = _selectedIndices.map((i) => list[i]).toList();
    
    for (var item in toRemove) {
      gp.removeFromPool(item);
    }
    
    setState(() {
      _selectedIndices.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${toRemove.length} kelime silindi.')),
    );
  }
}
