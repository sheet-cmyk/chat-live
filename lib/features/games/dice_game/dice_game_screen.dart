import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dice_game_panel.dart';

class DiceGameScreen extends StatelessWidget {
  const DiceGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'solo';
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: DiceGamePanel(
        roomId: 'solo_$uid',
        onClose: () => Navigator.pop(context),
      ),
    );
  }
}
