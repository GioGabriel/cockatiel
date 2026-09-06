import 'package:flutter/material.dart';

/// A responsive page shell for long briefings with a persistent primary action.
///
/// The briefing content can grow with larger text, localized copy, or backend
/// data without pushing the action off-screen or triggering a RenderFlex
/// overflow. The action remains available while the content scrolls.
class ScrollableActionLayout extends StatelessWidget {
  const ScrollableActionLayout({
    super.key,
    required this.content,
    required this.action,
    this.error,
  });

  final Widget content;
  final Widget action;
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    error!,
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: action,
            ),
          ),
        ],
      ),
    );
  }
}
