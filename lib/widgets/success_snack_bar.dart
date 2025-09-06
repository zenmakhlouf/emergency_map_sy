import 'package:flutter/material.dart';

showSuccessSnackBar({
  required String message,
  required BuildContext context,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.green,

    ),
  );
}