import 'package:flutter/material.dart';

/// A consistent, scrollable recovery state with one clear next action.
class StudioRecoveryView extends StatelessWidget {
  const StudioRecoveryView(
      {super.key,
      required this.title,
      required this.message,
      required this.onRetry,
      this.retryLabel = 'Retry'});
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - 48).clamp(0, double.infinity)),
                child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(24)),
                            child: Icon(Icons.cloud_off_rounded,
                                size: 32, color: theme.colorScheme.primary)),
                        const SizedBox(height: 24),
                        Semantics(
                            liveRegion: true,
                            child: Text(title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(height: 1.15))),
                        const SizedBox(height: 12),
                        Text(message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.6,
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(retryLabel)),
                      ])),
                ),
              ),
            ));
  }
}
