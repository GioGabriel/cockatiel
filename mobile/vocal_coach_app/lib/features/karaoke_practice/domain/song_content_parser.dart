import '../../../shared/models/session_models.dart';

class LyricLine {
  const LyricLine({required this.time, required this.text});
  final Duration time;
  final String text;
}

/// Invalid neighbors cannot discard a valid target; both supported map formats
/// converge on one chronological representation.
List<TrainingRuntimeStage> parseSongPitchMap(Object? data) {
  final points = <double, double>{};
  void add(Object? time, Object? pitch) {
    if (time is! num || pitch is! num) return;
    final t = time.toDouble();
    final hz = pitch.toDouble();
    if (!t.isFinite || t < 0 || !hz.isFinite || hz <= 0) return;
    points.putIfAbsent(t, () => hz);
  }

  if (data is List) {
    for (final item in data.whereType<Map>()) {
      add(item['time'], item['pitch']);
    }
  } else if (data is Map) {
    for (final entry in data.entries) {
      final parts = entry.key.toString().split(':');
      if (parts.length != 2) continue;
      final minutes = int.tryParse(parts[0]);
      final seconds = double.tryParse(parts[1]);
      if (minutes == null ||
          minutes < 0 ||
          seconds == null ||
          !seconds.isFinite ||
          seconds < 0 ||
          seconds >= 60) {
        continue;
      }
      add(minutes * 60 + seconds, entry.value);
    }
  }
  final times = points.keys.toList()..sort();
  return List.generate(times.length, (index) {
    final start = times[index];
    final duration = index + 1 < times.length
        ? (times[index + 1] - start).clamp(.01, .5)
        : .1;
    final hz = points[start]!;
    return TrainingRuntimeStage(
        stageId: 'pitch_$index',
        title: 'Note ${index + 1}',
        targetLabel: hz.toString(),
        instruction: 'Match pitch',
        durationSec: duration,
        startSec: start,
        endSec: start + duration);
  });
}

List<LyricLine> parseSongLyrics(String lrc) {
  final offset = int.tryParse(
          RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false)
                  .firstMatch(lrc)
                  ?.group(1) ??
              '') ??
      0;
  final timestamp = RegExp(r'\[(\d+):(\d{2})(?:\.(\d{1,3}))?\]');
  final lines = <LyricLine>[];
  for (final line in lrc.split('\n')) {
    final matches = timestamp.allMatches(line).toList();
    if (matches.isEmpty) continue;
    final text = line.substring(matches.last.end).trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final seconds = int.parse(match.group(2)!);
      if (seconds >= 60) continue;
      final milliseconds = int.parse((match.group(3) ?? '0').padRight(3, '0'));
      final time = int.parse(match.group(1)!) * 60000 +
          seconds * 1000 +
          milliseconds -
          offset;
      lines.add(LyricLine(
          time: Duration(milliseconds: time.clamp(0, 86400000)), text: text));
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}
