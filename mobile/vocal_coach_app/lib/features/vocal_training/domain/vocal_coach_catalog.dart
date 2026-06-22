import 'package:flutter/material.dart';

class VocalExercise {
  const VocalExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.objective,
    required this.whatYouDo,
    required this.requiresMicrophone,
    required this.exerciseMode,
    required this.instructions,
    required this.aiFocus,
    required this.difficulty,
    required this.focusMetrics,
    required this.recommendedOrder,
  });

  final String id;
  final String name;
  final String description;
  final String objective;
  final String whatYouDo;
  final bool requiresMicrophone;
  final String exerciseMode;
  final List<String> instructions;
  final String aiFocus;
  final String difficulty;
  final List<String> focusMetrics;
  final int recommendedOrder;
}

class VocalCoachCategory {
  const VocalCoachCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.exercises,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<VocalExercise> exercises;
}

const vocalCoachCatalog = <VocalCoachCategory>[
  VocalCoachCategory(
    id: 'vocal_training',
    title: 'Vocal Training',
    subtitle: 'Tone, resonance, control, and transitions.',
    description:
        'Core vocal technique drills for placement, warmup, and note connection.',
    icon: Icons.mic_external_on_outlined,
    exercises: [
      VocalExercise(
        id: 'resonance_placement',
        name: 'Resonance Placement',
        description:
            'Sustain open vowels and place tone forward without throat tension.',
        objective:
            'Build forward, efficient resonance without tightening the throat.',
        whatYouDo:
            'Hum and sustain light notes while keeping the tone bright, relaxed, and forward.',
        requiresMicrophone: true,
        exerciseMode: 'voice',
        instructions: [
          'Keep jaw and neck relaxed.',
          'Sustain open vowels at stable airflow.',
          'Aim tone forward without squeezing.',
        ],
        aiFocus: 'Tone color, resonance consistency, and projection efficiency',
        difficulty: 'Beginner',
        focusMetrics: ['Breath control', 'Pitch stability', 'Pitch accuracy'],
        recommendedOrder: 1,
      ),
      VocalExercise(
        id: 'warmup_pitch',
        name: 'Pitch Warmup',
        description:
            'Warm the voice with controlled pitch center and gentle onset.',
        objective:
            'Center the voice with clean onsets and stable warmup pitch.',
        whatYouDo:
            'Sing a short note ladder softly, landing each note cleanly before moving to the next one.',
        requiresMicrophone: true,
        exerciseMode: 'voice',
        instructions: [
          'Start softly and increase gradually.',
          'Hold each note 2-3 seconds.',
          'Prioritize steady tone over volume.',
        ],
        aiFocus: 'Pitch center, onset consistency, and warmup control',
        difficulty: 'Beginner',
        focusMetrics: ['Pitch accuracy', 'Timing accuracy', 'Pitch stability'],
        recommendedOrder: 2,
      ),
      VocalExercise(
        id: 'note_transition_drill',
        name: 'Note Transition Drill',
        description:
            'Move between adjacent notes smoothly with stable airflow.',
        objective:
            'Connect notes with controlled transitions and faster pitch settling.',
        whatYouDo:
            'Sing connected note changes without scooping, dragging, or jumping too hard between pitches.',
        requiresMicrophone: true,
        exerciseMode: 'voice',
        instructions: [
          'Connect notes in legato style.',
          'Avoid abrupt jumps or glides.',
          'Keep breath pressure even.',
        ],
        aiFocus: 'Transition stability, pitch settling speed, and control',
        difficulty: 'Intermediate',
        focusMetrics: [
          'Transition smoothness',
          'Timing accuracy',
          'Pitch stability',
        ],
        recommendedOrder: 3,
      ),
    ],
  ),
  VocalCoachCategory(
    id: 'do_re_mi',
    title: 'Do Re Mi',
    subtitle: 'Pitch-target drills and ear-voice alignment.',
    description:
        'Develop note recognition, interval awareness, and scale accuracy.',
    icon: Icons.tune_rounded,
    exercises: [
      VocalExercise(
        id: 'do_re_mi_basic_ladder',
        name: 'Basic Ladder',
        description: 'Step through Do Re Mi Fa Sol with stable intonation.',
        objective: 'Strengthen basic scale control and pitch targeting.',
        whatYouDo:
            'Sing one target note at a time in order, matching each step before climbing to the next one.',
        requiresMicrophone: true,
        exerciseMode: 'voice',
        instructions: [
          'Follow target notes in order.',
          'Hold each note until stable.',
          'Reset breath between phrases.',
        ],
        aiFocus: 'Pitch lock per target note and cents error trend',
        difficulty: 'Beginner',
        focusMetrics: ['Pitch accuracy', 'Timing accuracy', 'Pitch stability'],
        recommendedOrder: 1,
      ),
      VocalExercise(
        id: 'do_re_mi_interval_jumps',
        name: 'Interval Jumps',
        description: 'Leap between non-adjacent scale tones cleanly.',
        objective: 'Improve direct landing on larger intervals.',
        whatYouDo:
            'Hear the next note in your mind, then jump directly to it without sliding into the pitch.',
        requiresMicrophone: true,
        exerciseMode: 'voice',
        instructions: [
          'Visualize target before singing.',
          'Land directly without sliding.',
          'Stabilize quickly after each jump.',
        ],
        aiFocus: 'Landing precision and interval recovery speed',
        difficulty: 'Advanced',
        focusMetrics: ['Pitch accuracy', 'Transition smoothness', 'Timing'],
        recommendedOrder: 2,
      ),
    ],
  ),
  VocalCoachCategory(
    id: 'breathing',
    title: 'Breathing',
    subtitle: 'Breath support, phrase length, and airflow consistency.',
    description: 'Train support, airflow pacing, and phrase endurance.',
    icon: Icons.air_rounded,
    exercises: [
      VocalExercise(
        id: 'breath_support_ladder',
        name: 'Support Ladder',
        description:
            'Follow guided inhale and exhale counts to build steady breath support.',
        objective:
            'Develop support consistency over gradually longer inhale and exhale cycles.',
        whatYouDo:
            'Follow the timer to inhale, settle, and exhale slowly through each guided breathing cycle.',
        requiresMicrophone: false,
        exerciseMode: 'breathing_timer',
        instructions: [
          'Inhale low and relaxed.',
          'Exhale at consistent pressure for the full count.',
          'Keep shoulders relaxed while the timer guides you.',
        ],
        aiFocus: 'Breath consistency, loudness stability, and endurance',
        difficulty: 'Beginner',
        focusMetrics: [
          'Phase completion',
          'Pace adherence',
          'Cycle consistency',
        ],
        recommendedOrder: 1,
      ),
      VocalExercise(
        id: 'long_phrase_breathing',
        name: 'Long Phrase Breathing',
        description:
            'Practice longer inhale-to-exhale cycles that mimic phrase-length breath pacing.',
        objective: 'Improve airflow pacing and phrase-end stability.',
        whatYouDo:
            'Use the timer to inhale, then stretch a calm, even exhale for longer phrase-style counts.',
        requiresMicrophone: false,
        exerciseMode: 'breathing_timer',
        instructions: [
          'Inhale quietly before each cycle.',
          'Pace the exhale instead of pushing air out early.',
          'Stay relaxed until the end of the count.',
        ],
        aiFocus: 'Breath planning, support retention, and phrase completion',
        difficulty: 'Intermediate',
        focusMetrics: [
          'Phase completion',
          'Pace adherence',
          'Completion rate',
        ],
        recommendedOrder: 2,
      ),
    ],
  ),
];
