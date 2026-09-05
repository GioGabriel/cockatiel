import 'package:flutter/material.dart';

import '../../../core/audio/pitch/voice_type_classifier.dart';
import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/user_models.dart';
import '../../user_profile/presentation/voice_calibration_page.dart';

/// A short, optional post-auth step that turns the existing calibration flow
/// into a discoverable first-run setup without blocking the rest of the app.
class VoiceProfileSetupPage extends StatefulWidget {
  const VoiceProfileSetupPage({
    super.key,
    required this.appState,
    required this.apiClient,
    required this.onFinished,
  });

  final AppState appState;
  final ApiClient apiClient;
  final VoidCallback onFinished;

  @override
  State<VoiceProfileSetupPage> createState() => _VoiceProfileSetupPageState();
}

class _VoiceProfileSetupPageState extends State<VoiceProfileSetupPage> {
  bool _isSaving = false;
  String? _errorMessage;
  VoiceTypeResult? _pendingResult;

  Future<void> _startSetup() async {
    final result = await Navigator.of(context).push<VoiceTypeResult>(
      MaterialPageRoute(builder: (_) => const VoiceCalibrationPage()),
    );
    if (!mounted || result == null) return;

    _pendingResult = result;
    await _saveResult(result);
  }

  Future<void> _saveResult(VoiceTypeResult result) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final update = VocalPreferencesUpdate(
        vocalRange: _rangeFromVoiceType(result.voiceType),
        preferredCategories: const ['vocal_training'],
        trainingGoal: TrainingGoal.generalSkillBuilding,
        voiceCalibration: _calibrationFromResult(result),
      );
      final profile = await widget.apiClient.updateVocalPreferences(update);
      widget.appState.updateCurrentUserProfile(profile);
      if (!mounted) return;
      widget.onFinished();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.message.isNotEmpty
            ? error.message
            : 'We could not save your voice profile. You can try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage =
            'We could not save your voice profile. You can try again.';
      });
    }
  }

  VoiceCalibration _calibrationFromResult(VoiceTypeResult result) {
    return VoiceCalibration(
      voiceType: _rangeFromVoiceType(result.voiceType),
      confidence: result.confidence,
      averageFrequencyHz: result.averageFrequencyHz,
      lowestFrequencyHz: result.lowestFrequencyHz,
      highestFrequencyHz: result.highestFrequencyHz,
      sampleCount: result.sampleCount,
      calibratedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  VocalRange _rangeFromVoiceType(VoiceType voiceType) {
    switch (voiceType) {
      case VoiceType.soprano:
        return VocalRange.soprano;
      case VoiceType.mezzoSoprano:
        return VocalRange.mezzoSoprano;
      case VoiceType.alto:
        return VocalRange.alto;
      case VoiceType.tenor:
        return VocalRange.tenor;
      case VoiceType.baritone:
        return VocalRange.baritone;
      case VoiceType.bass:
        return VocalRange.bass;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your voice profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              size: 56,
              color: theme.colorScheme.primary,
              semanticLabel: 'Voice profile',
            ),
            const SizedBox(height: 20),
            Text(
              'Make your practice feel personal',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'A short microphone check estimates a comfortable starting range so exercises and songs can be easier to follow.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This is only a practice estimate—not a diagnosis, identity, or gender label. You can change it or calibrate again anytime.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your microphone is analyzed on this device. Cockatiel saves the numeric calibration summary, not a raw voice recording.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _isSaving ? null : _startSetup,
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Start voice setup'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSaving ? null : widget.onFinished,
              child: const Text('Skip for now'),
            ),
            if (_isSaving) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              if (_pendingResult != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () {
                          final pending = _pendingResult;
                          if (pending != null) _saveResult(pending);
                        },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try saving again'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
