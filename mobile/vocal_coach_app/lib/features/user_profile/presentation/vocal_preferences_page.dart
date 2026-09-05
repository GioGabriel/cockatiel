import 'package:flutter/material.dart';

import 'package:vocal_coach_app/shared/animations/spring_curves.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/audio/pitch/voice_type_classifier.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/user_models.dart';
import 'voice_calibration_page.dart';

class VocalPreferencesPage extends StatefulWidget {
  const VocalPreferencesPage({
    super.key,
    required this.apiClient,
    this.currentPreferences,
  });

  final ApiClient apiClient;
  final VocalPreferences? currentPreferences;

  @override
  State<VocalPreferencesPage> createState() => _VocalPreferencesPageState();
}

class _VocalPreferencesPageState extends State<VocalPreferencesPage> {
  final _formKey = GlobalKey<FormState>();

  late VocalRange? _selectedRange;
  late TrainingGoal _selectedGoal;
  late Set<String> _selectedCategories;
  VoiceCalibration? _voiceCalibration;

  bool _isSaving = false;
  String? _errorMessage;

  static const _availableCategories = [
    'vocal_training',
    'do_re_mi',
    'breathing',
    'karaoke',
  ];

  static const _categoryLabels = {
    'vocal_training': 'Vocal Training',
    'do_re_mi': 'Do Re Mi',
    'breathing': 'Breathing',
    'karaoke': 'Karaoke',
  };

  @override
  void initState() {
    super.initState();
    final prefs = widget.currentPreferences;
    _selectedRange = prefs?.vocalRange;
    _selectedGoal = prefs?.trainingGoal ?? TrainingGoal.generalSkillBuilding;
    _selectedCategories = prefs != null
        ? Set<String>.from(prefs.preferredCategories)
        : <String>{};
    _voiceCalibration = prefs?.voiceCalibration;
  }

  String _vocalRangeLabel(VocalRange range) {
    switch (range) {
      case VocalRange.soprano:
        return 'Soprano';
      case VocalRange.mezzoSoprano:
        return 'Mezzo-Soprano';
      case VocalRange.alto:
        return 'Alto';
      case VocalRange.tenor:
        return 'Tenor';
      case VocalRange.baritone:
        return 'Baritone';
      case VocalRange.bass:
        return 'Bass';
    }
  }

  String _trainingGoalLabel(TrainingGoal goal) {
    switch (goal) {
      case TrainingGoal.pitchImprovement:
        return 'Pitch Improvement';
      case TrainingGoal.breathControl:
        return 'Breath Control';
      case TrainingGoal.toneQuality:
        return 'Tone Quality';
      case TrainingGoal.rangeExtension:
        return 'Range Extension';
      case TrainingGoal.generalSkillBuilding:
        return 'General Skill Building';
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else if (_selectedCategories.length < 3) {
        _selectedCategories.add(category);
      }
      _errorMessage = null;
    });
  }

  Future<void> _openVoiceCalibration() async {
    final result = await Navigator.of(context).push<VoiceTypeResult>(
      MaterialPageRoute(builder: (_) => const VoiceCalibrationPage()),
    );
    if (result == null || !mounted) return;

    // Map detected voice type to the VocalRange enum.
    final detectedRange = _voiceTypeToVocalRange(result.voiceType);
    setState(() {
      _selectedRange = detectedRange;
      _voiceCalibration = VoiceCalibration(
        voiceType: detectedRange,
        confidence: result.confidence,
        averageFrequencyHz: result.averageFrequencyHz,
        lowestFrequencyHz: result.lowestFrequencyHz,
        highestFrequencyHz: result.highestFrequencyHz,
        sampleCount: result.sampleCount,
        calibratedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  VocalRange _voiceTypeToVocalRange(VoiceType voiceType) {
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

  Future<void> _onSubmit() async {
    if (_selectedCategories.isEmpty) {
      setState(() {
        _errorMessage = 'Select at least 1 category.';
      });
      return;
    }

    if (_selectedRange == null) {
      setState(() {
        _errorMessage = 'Choose a vocal range or run calibration first.';
      });
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final update = VocalPreferencesUpdate(
        vocalRange: _selectedRange!,
        preferredCategories: _selectedCategories.toList(),
        trainingGoal: _selectedGoal,
        voiceCalibration: _voiceCalibration,
      );
      final updatedProfile =
          await widget.apiClient.updateVocalPreferences(update);

      if (!mounted) return;
      Navigator.of(context).pop(updatedProfile);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.appTokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice profile and preferences'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vocal Range',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This is a practice estimate, not a diagnosis or identity label. You can change it anytime.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openVoiceCalibration,
                      icon: Icon(Icons.mic_rounded,
                          color: theme.colorScheme.primary),
                      label: Text(
                        _voiceCalibration == null
                            ? 'Calibrate my voice'
                            : 'Run calibration again',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    if (_voiceCalibration != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Estimated ${_vocalRangeLabel(_voiceCalibration!.voiceType)} · '
                        '${(_voiceCalibration!.confidence * 100).round()}% confidence · '
                        '${_voiceCalibration!.lowestFrequencyHz.round()}–${_voiceCalibration!.highestFrequencyHz.round()} Hz',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<VocalRange>(
                      initialValue: _selectedRange,
                      hint: const Text('Choose a range or calibrate'),
                      style: theme.textTheme.bodyLarge,
                      dropdownColor: theme.colorScheme.surfaceContainerHighest,
                      iconEnabledColor: theme.colorScheme.primary,
                      items: VocalRange.values.map((range) {
                        return DropdownMenuItem(
                          value: range,
                          child: Text(_vocalRangeLabel(range)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRange = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preferred Categories',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select up to 3 categories',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _availableCategories.map((category) {
                        final selected = _selectedCategories.contains(category);
                        final scaleVal = selected ? 1.0 : 0.95;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: kDefaultSpringCurve,
                          transform: Matrix4.diagonal3Values(
                            scaleVal,
                            scaleVal,
                            1.0,
                          ),
                          child: FilterChip(
                            label: Text(
                              _categoryLabels[category] ?? category,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: selected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: selected,
                            selectedColor: theme.colorScheme.primary,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            checkmarkColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                              ),
                            ),
                            onSelected: (_) => _toggleCategory(category),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_errorMessage != null &&
                        _selectedCategories.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: tokens.danger),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Training Goal',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<TrainingGoal>(
                      initialValue: _selectedGoal,
                      style: theme.textTheme.bodyLarge,
                      dropdownColor: theme.colorScheme.surfaceContainerHighest,
                      iconEnabledColor: theme.colorScheme.primary,
                      items: TrainingGoal.values.map((goal) {
                        return DropdownMenuItem(
                          value: goal,
                          child: Text(_trainingGoalLabel(goal)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedGoal = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null && _selectedCategories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: tokens.danger),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _onSubmit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save preferences'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}
