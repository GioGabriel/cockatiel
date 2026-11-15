import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/models/session_models.dart';
import '../../../shared/widgets/voice_studio.dart';
import 'feedback_page.dart';

/// Follows the saved take itself so optional queued feedback cannot disappear
/// behind an unrelated list of jobs. Polling is bounded and never overlaps.
class SessionFeedbackWaitPage extends StatefulWidget {
  const SessionFeedbackWaitPage(
      {super.key,
      required this.loadReview,
      required this.onOpenQueue,
      this.requestTimeout = const Duration(seconds: 12)});
  final Future<FinalizeResponse> Function() loadReview;
  final VoidCallback onOpenQueue;
  final Duration requestTimeout;
  @override
  State<SessionFeedbackWaitPage> createState() =>
      _SessionFeedbackWaitPageState();
}

class _SessionFeedbackWaitPageState extends State<SessionFeedbackWaitPage> {
  Timer? _timer;
  FinalizeResponse? _result;
  bool _loading = false;
  bool _paused = false;
  int _polls = 0;
  int _failures = 0;
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _polls = 0;
    _failures = 0;
    _paused = false;
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_loading || !mounted) return;
    _loading = true;
    _polls++;
    try {
      final result = await widget.loadReview().timeout(widget.requestTimeout);
      if (!mounted) return;
      _failures = 0;
      if (result.feedback != null) {
        _timer?.cancel();
        setState(() => _result = result);
        return;
      }
      if (result.status == 'failed') _pause();
    } catch (_) {
      _failures++;
      if (_failures >= 3 && mounted) _pause();
    } finally {
      _loading = false;
      if (_polls >= 30 && mounted && _result == null) _pause();
    }
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _paused = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return FeedbackPage(result: _result!);
    return Scaffold(
      appBar: AppBar(title: const Text('Song review')),
      body: VoiceStageBackground(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const VoiceHero(size: 180),
                    Text('Your take is saved',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(
                        _paused
                            ? 'Feedback is taking longer than expected. Your take stays available in saved reviews.'
                            : 'Preparing your coaching review. It will open here as soon as it is ready.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    if (!_paused) const CircularProgressIndicator(),
                    if (_paused)
                      FilledButton(
                          onPressed: () {
                            setState(_start);
                          },
                          child: const Text('Try again')),
                    const SizedBox(height: 12),
                    TextButton(
                        onPressed: widget.onOpenQueue,
                        child: const Text('Open saved reviews')),
                  ])))),
    );
  }
}
