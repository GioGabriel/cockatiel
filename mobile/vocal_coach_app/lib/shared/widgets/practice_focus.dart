import 'package:flutter/material.dart';
import 'voice_studio.dart';

/// Focused live surface: the visual gets at least half the available viewport.
class PracticeFocus extends StatelessWidget {
  const PracticeFocus(
      {super.key,
      required this.title,
      required this.cue,
      required this.secondsRemaining,
      required this.progress,
      required this.visual,
      required this.onFinish,
      this.finishLabel = 'Finish take'});
  final String title;
  final String cue;
  final int secondsRemaining;
  final double progress;
  final Widget visual;
  final VoidCallback onFinish;
  final String finishLabel;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: false),
      body: VoiceStageBackground(
          child: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.mic_rounded),
              const SizedBox(width: 8),
              const Expanded(child: Text('LIVE PRACTICE')),
              Text('${secondsRemaining}s', style: theme.textTheme.titleLarge)
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(
                value: progress.clamp(0, 1),
                borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 16),
            Text(cue,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            SizedBox(
                key: const Key('practice-focus-visual'),
                height: constraints.maxHeight * .52,
                child: visual),
            const SizedBox(height: 16),
            const Text('Keep it comfortable. Stop if you feel strain.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.stop_rounded),
                label: Text(finishLabel)),
          ]),
        ));
      }))),
    );
  }
}
