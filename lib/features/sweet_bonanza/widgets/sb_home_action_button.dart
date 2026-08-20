import 'package:flutter/material.dart';

class SbHomeActionButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const SbHomeActionButton(
      {super.key, required this.text, required this.onPressed});

  @override
  State<SbHomeActionButton> createState() => _SbHomeActionButtonState();
}

class _SbHomeActionButtonState extends State<SbHomeActionButton> {
  double _scale = 1.0;

  void _animatePress() async {
    setState(() => _scale = 0.9);
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _scale = 1.0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _animatePress,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(76),
                offset: const Offset(2, 4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(
            widget.text,
            style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
