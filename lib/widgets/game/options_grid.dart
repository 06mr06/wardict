import 'package:flutter/material.dart';

class OptionsGrid extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final int correctIndex;
  final bool isLocked;
  final bool showCorrect;
  final Function(int) onOptionSelected;
  final Set<int> eliminatedOptions; // For 50/50 powerup

  const OptionsGrid({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.correctIndex,
    required this.onOptionSelected,
    this.isLocked = false,
    this.showCorrect = false,
    this.eliminatedOptions = const {},
  });

  @override
  Widget build(BuildContext context) {
    // 2x2 Layout using Flexible Rows/Columns to prevent overflow
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildOption(0)),
              const SizedBox(width: 12),
              Expanded(child: _buildOption(1)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildOption(2)),
              const SizedBox(width: 12),
              Expanded(child: _buildOption(3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOption(int i) {
    final bool reveal = showCorrect || (selectedIndex != null && isLocked);
    final isEliminated = eliminatedOptions.contains(i);
    final isSelected = selectedIndex == i;
    
    // 3D Button Colors
    Color topColor;
    Color bottomColor;
    Color shadowColor; // Solid color for 3D block side
    Color textColor;
    double depth = 8.0; // Thicker 3D effect
    double pressOffset = 0.0;

    if (isEliminated && !reveal) {
        topColor = Colors.grey.shade200;
        bottomColor = Colors.grey.shade300;
        shadowColor = Colors.grey.shade500;
        textColor = Colors.grey.shade500;
        depth = 4.0;
    } else if (reveal) {
      if (i == correctIndex) {
        // Correct Green
        topColor = const Color(0xFF4ADE80);
        bottomColor = const Color(0xFF22C55E);
        shadowColor = const Color(0xFF15803D); // Dark Green Solid
        textColor = Colors.white;
      } else if (isSelected) {
        // Wrong Red
        topColor = const Color(0xFFF87171);
        bottomColor = const Color(0xFFEF4444);
        shadowColor = const Color(0xFFB91C1C); // Dark Red Solid
        textColor = Colors.white;
      } else {
        // Unselected options during reveal
         topColor = Colors.grey.shade100;
         bottomColor = Colors.grey.shade200;
         shadowColor = Colors.grey.shade400;
         textColor = Colors.grey.shade600;
      }
    } else if (isSelected) {
        // Selected Blue (Waiting)
        topColor = const Color(0xFF60A5FA);
        bottomColor = const Color(0xFF3B82F6);
        shadowColor = const Color(0xFF1D4ED8); // Dark Blue Solid
        textColor = Colors.white;
        depth = 2.0; // Pressed physically
        pressOffset = 6.0; // Visual offset
    } else {
        // Default White (Physical Block)
        topColor = Colors.white;
        bottomColor = const Color(0xFFF3F4F6);
        shadowColor = const Color(0xFF9CA3AF); // Solid Grey for depth
        textColor = const Color(0xFF1F2937);
    }

    return GestureDetector(
      onTap: (isLocked || isEliminated) ? null : () => onOptionSelected(i),
      child: Container(
        height: 80, // Force height to ensure consistency
        margin: EdgeInsets.only(top: pressOffset), 
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: shadowColor, // The 3D side color
          boxShadow: [
             // Soft shadow below the entire block
             BoxShadow(
               color: Colors.black.withOpacity(0.2),
               blurRadius: 8,
               offset: const Offset(0, 4),
             )
          ]
        ),
        child: Container(
          margin: EdgeInsets.only(bottom: depth), // This creates the 3D 'side' visibility
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [topColor, bottomColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.5), 
              width: 1.5
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isEliminated ? '' : options[i],
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              if (isEliminated)
                 const Icon(Icons.close, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
