import 'package:flutter/material.dart';
import '../../widgets/lugo_mascot.dart';

class MatchmakingLugoDialog extends StatelessWidget {
  final String message;
  const MatchmakingLugoDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LugoMascot(
            message: message,
            size: 140,
          ),
        ],
      ),
    );
  }
}
