import 'package:flutter/material.dart';

class CustomElevatedButton extends StatelessWidget {
  final String label;
  final double? width;
  final double? height;
  final double? elevation;
  final OutlinedBorder? shape;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final void Function()? onPressed;

  const CustomElevatedButton({
    required this.label,
    required this.onPressed,
    this.shape,
    this.width,
    this.height,
    this.elevation,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        elevation: elevation,
        backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: foregroundColor ?? Theme.of(context).colorScheme.onPrimaryContainer,
        shape: shape ?? RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: foregroundColor),
      ),
    );
  }
}
