import 'package:flutter/material.dart';

class SbGameControlButton extends StatefulWidget {
  final String? label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final IconData? icon;
  final Color? iconColor;
  final String? assetPath;
  final double? width;
  final double? height;

  const SbGameControlButton({
    super.key,
    this.label,
    this.onPressed,
    this.backgroundColor,
    this.icon,
    this.iconColor,
    this.assetPath,
    this.width,
    this.height,
  });

  @override
  State<SbGameControlButton> createState() => _SbGameControlButtonState();
}

class _SbGameControlButtonState extends State<SbGameControlButton> {
  double _scale = 1.0;

  void _animatePress() async {
    if (widget.onPressed == null) return;
    setState(() => _scale = 0.9);
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _scale = 1.0);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    Widget buttonContent;
    if (widget.assetPath != null) {
      buttonContent = Image.asset(
        widget.assetPath!,
        width: widget.width ?? 64,
        height: widget.height ?? 64,
        fit: BoxFit.contain,
      );
    } else if (widget.icon != null) {
      buttonContent = Icon(
        widget.icon,
        color: widget.iconColor ?? Colors.white,
        size: 32,
      );
    } else {
      buttonContent = Text(
        widget.label ?? '',
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      );
    }

    return GestureDetector(
      onTap: isDisabled ? null : _animatePress,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: widget.assetPath != null
              ? buttonContent
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDisabled
                        ? Colors.grey
                        : (widget.backgroundColor ?? Colors.orange),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(24),
                  ),
                  onPressed: widget.onPressed,
                  child: buttonContent,
                ),
        ),
      ),
    );
  }
}
