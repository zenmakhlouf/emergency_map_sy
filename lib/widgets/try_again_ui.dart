import 'package:flutter/material.dart';

class TryAgainUi extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? debugMessage;

  const TryAgainUi({
    super.key,
    required this.message,
    this.onRetry,
    this.debugMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (debugMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                debugMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            if (onRetry != null)
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Try Again'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
