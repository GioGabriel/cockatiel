import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/animations/page_transitions.dart';
import '../../vocal_training/presentation/training_session_page.dart';

class KaraokeSessionSetupPage extends StatefulWidget {
  const KaraokeSessionSetupPage({
    super.key,
    required this.apiClient,
    required this.appState,
    required this.title,
    required this.exerciseOptions,
  });

  final ApiClient apiClient;
  final AppState appState;
  final String title;
  final List<String> exerciseOptions;

  @override
  State<KaraokeSessionSetupPage> createState() =>
      _KaraokeSessionSetupPageState();
}

class _KaraokeSessionSetupPageState extends State<KaraokeSessionSetupPage> {
  late String _selectedExercise = widget.exerciseOptions.first;
  bool _isStarting = false;
  String? _error;

  Future<void> _startSession() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      final created = await widget.apiClient.createSession(
        mode: 'karaoke',
        exerciseType: _selectedExercise,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        slideUpRoute(
          builder: (_) => TrainingSessionPage(
            apiClient: widget.apiClient,
            appState: widget.appState,
            mode: 'karaoke',
            exerciseType: _selectedExercise,
            sessionId: created.sessionId,
          ),
        ),
      );
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Karaoke Setup',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a karaoke drill before starting the live session.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedExercise,
                      decoration: const InputDecoration(
                        labelText: 'Karaoke drill',
                      ),
                      items: widget.exerciseOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: _isStarting
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedExercise = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isStarting ? null : _startSession,
                      child:
                          Text(_isStarting ? 'Starting...' : 'Start Karaoke'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
