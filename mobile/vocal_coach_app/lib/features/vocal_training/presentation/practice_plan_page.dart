import 'package:vocal_coach_app/shared/widgets/studio_scaffold.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/voice_studio.dart';

class PracticePlanPage extends StatelessWidget {
  const PracticePlanPage(
      {super.key, required this.onTrain, required this.onSong});
  final VoidCallback onTrain;
  final VoidCallback onSong;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StudioScaffold(
        maxContentWidth: 800,
        appBar: AppBar(title: const Text('Your practice rhythm')),
        body: VoiceStageBackground(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          const StudioHeading(
              eyebrow: 'BUILD YOUR RHYTHM',
              title: 'A little, often.',
              description:
                  'Start with a comfortable 15–30 minute session, 4–6 days a week. Shorter sessions are welcome. Rest when your voice feels tired.'),
          const SizedBox(height: 20),
          for (final step in const [
            (
              '01',
              'Warm up · 5 minutes',
              'Gentle humming, lip trills and a small three-to-five-note pattern.'
            ),
            (
              '02',
              'One technique · 10 minutes',
              'Choose pitch matching, breathing or smooth note changes. Work on one goal.'
            ),
            (
              '03',
              'Apply it to a song · 5 minutes',
              'Repeat one comfortable phrase with the backing track, then review your take.'
            ),
            (
              '04',
              'Cool down · 2 minutes',
              'A gentle descending hum, then note one improvement and one next step.'
            ),
          ])
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StudioCard(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(step.$1,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(color: theme.colorScheme.primary)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(step.$2, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(step.$3),
                          ])),
                    ]))),
          FilledButton.icon(
              onPressed: onTrain,
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Start a guided exercise')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: onSong,
              icon: const Icon(Icons.music_note_rounded),
              label: const Text('Choose a church song')),
          const SizedBox(height: 16),
          const Card(
              child: ExpansionTile(title: Text('A balanced week'), children: [
            ListTile(title: Text('Mon · Breath and pitch')),
            ListTile(title: Text('Tue · One technique')),
            ListTile(title: Text('Wed · Song phrases')),
            ListTile(title: Text('Thu · Listening and rhythm')),
            ListTile(title: Text('Fri · Expression')),
            ListTile(title: Text('Sat · A comfortable full take')),
            ListTile(title: Text('Sun · Rest and reflect')),
          ])),
          const Card(
              child: ExpansionTile(
                  title: Text('Music basics, one step at a time'),
                  children: [
                ListTile(
                    title: Text('Pitch'),
                    subtitle: Text(
                        'How high or low a note sounds. Match a reference at a comfortable volume.')),
                ListTile(
                    title: Text('Rhythm'),
                    subtitle: Text(
                        'When a note starts and how long it lasts. Clap a short pattern before singing.')),
                ListTile(
                    title: Text('Keys and solfège'),
                    subtitle: Text(
                        'Do–re–mi describes the relationships between notes. The selected key gives Do its actual pitch.')),
                ListTile(
                    title: Text('Intervals'),
                    subtitle: Text(
                        'The distance between two notes. Start with nearby notes before larger leaps.')),
              ])),
          const Card(
              child:
                  ExpansionTile(title: Text('Build over 12 weeks'), children: [
            ListTile(
                title: Text('Weeks 1–4 · Foundations'),
                subtitle: Text(
                    'Gentle warm-ups, single-note matching and one short weekly song recording.')),
            ListTile(
                title: Text('Weeks 5–8 · Control'),
                subtitle: Text(
                    'Comfortable scales, held notes and a few song phrases. Compare with your own earlier takes.')),
            ListTile(
                title: Text('Weeks 9–12 · Expression'),
                subtitle: Text(
                    'Practice a full song, phrasing and recovering from mistakes. Ask a teacher or choir director for feedback.')),
          ])),
          const SizedBox(height: 16),
          const Text(
              'These are flexible practice suggestions, not medical standards or a promise of improvement. Stop for pain, dizziness, hoarseness or strain. Seek qualified help for persistent voice symptoms.'),
        ])));
  }
}
