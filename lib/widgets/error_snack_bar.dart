import 'package:flutter/material.dart';

showErrorSnackBar({
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
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}
