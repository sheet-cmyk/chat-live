import 'package:flutter/material.dart';

class SbPrivacyPolicyScreen extends StatelessWidget {
  const SbPrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.grey,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            'This game is for entertainment purposes only. No real money is involved. '
            'Virtual coins have no real-world value and cannot be exchanged for cash or prizes.',
            style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
          ),
        ),
      ),
    );
  }
}
