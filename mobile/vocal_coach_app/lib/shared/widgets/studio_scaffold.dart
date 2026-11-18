import 'package:flutter/material.dart';

/// A shared reading grid for the app. Scrollables receive bounded constraints,
/// rather than painting phone-sized controls across an entire desktop window.
class StudioScaffold extends StatelessWidget {
  const StudioScaffold(
      {super.key,
      this.appBar,
      this.body,
      this.bottomNavigationBar,
      this.backgroundColor,
      this.resizeToAvoidBottomInset,
      this.extendBody = false,
      this.floatingActionButton,
      this.bottomSheet,
      this.maxContentWidth = 1040});
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody;
  final Widget? floatingActionButton;
  final Widget? bottomSheet;
  final double maxContentWidth;

  Widget _bounded(Widget child, double width) => Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: SizedBox(width: double.infinity, child: child)));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        extendBody: extendBody,
        appBar: appBar == null
            ? null
            : PreferredSize(
                preferredSize: appBar!.preferredSize,
                child: _bounded(appBar!, maxContentWidth)),
        body: body == null ? null : _bounded(body!, maxContentWidth),
        bottomNavigationBar: bottomNavigationBar == null
            ? null
            : _bounded(bottomNavigationBar!, 680),
        floatingActionButton: floatingActionButton,
        bottomSheet: bottomSheet,
      );
}

class StudioHeading extends StatelessWidget {
  const StudioHeading(
      {super.key,
      required this.eyebrow,
      required this.title,
      this.description});
  final String eyebrow;
  final String title;
  final String? description;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.8,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(title,
              style: theme.textTheme.headlineLarge
                  ?.copyWith(letterSpacing: -1, height: 1.12)),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.6)),
          ],
        ]));
  }
}
