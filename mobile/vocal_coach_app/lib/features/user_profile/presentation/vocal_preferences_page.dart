import 'package:flutter/material.dart';

import 'package:vocal_coach_app/shared/animations/spring_curves.dart';

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

  late VocalRange _selectedRange;
  late TrainingGoal _selectedGoal;
  late Set<String> _selectedCategories;

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
    _selectedRange = prefs?.vocalRange ?? VocalRange.tenor;
    _selectedGoal = prefs?.trainingGoal ?? TrainingGoal.generalSkillBuilding;
    _selectedCategories = prefs != null
        ? Set<String>.from(prefs.preferredCategories)
        : <String>{};
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

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final update = VocalPreferencesUpdate(
        vocalRange: _selectedRange,
        preferredCategories: _selectedCategories.toList(),
        trainingGoal: _selectedGoal,
      );
      final updatedProfile =
          await widget.apiClient.updateVocalPreferences(update);

      if (!mounted) return;
      Navigator.of(context).pop(updatedProfile);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save preferences. (${e.statusCode})';
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Vocal Preferences',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        color: const Color(0xFF0A0A0F),
        child: SafeArea(
          child: Form(
            key: _formKey,
        child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vocal Range',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Not sure? Let us detect it automatically.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _openVoiceCalibration,
                        icon: const Icon(Icons.mic_rounded, color: Colors.cyanAccent),
                        label: const Text(
                          'DETECT MY VOICE TYPE',
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: const Color(0xFF1E1E2C),
                        ),
                        child: DropdownButtonFormField<VocalRange>(
                          initialValue: _selectedRange,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.cyanAccent),
                            ),
                          ),
                          dropdownColor: const Color(0xFF1A1A2E),
                          iconEnabledColor: Colors.cyanAccent,
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preferred Categories',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select up to 3 categories',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _availableCategories.map((category) {
                          final selected =
                              _selectedCategories.contains(category);
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
                                style: TextStyle(
                                  color: selected ? Colors.black : Colors.white,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selected: selected,
                              selectedColor: Colors.purpleAccent,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              checkmarkColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: selected
                                      ? Colors.purpleAccent
                                      : Colors.white.withValues(alpha: 0.2),
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
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
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
                      const Text(
                        'Training Goal',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: const Color(0xFF1E1E2C),
                        ),
                        child: DropdownButtonFormField<TrainingGoal>(
                          initialValue: _selectedGoal,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.purpleAccent),
                            ),
                          ),
                          dropdownColor: const Color(0xFF1A1A2E),
                          iconEnabledColor: Colors.purpleAccent,
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
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null &&
                    _selectedCategories.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'SAVE PREFERENCES',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF282828), width: 1),
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
