import 'package:flutter/material.dart';

/// Actual cover art when present; an intentional record sleeve when absent.
class SongArtwork extends StatelessWidget {
  const SongArtwork({super.key, required this.title, this.coverUrl = ''});
  final String title;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final swatches = [
      const Color(0xFFBCA4E5),
      const Color(0xFF9BC7BC),
      const Color(0xFFDEB8AA),
      const Color(0xFF9DAED2)
    ];
    final index =
        title.runes.fold<int>(0, (sum, rune) => sum + rune) % swatches.length;
    final fallback = CustomPaint(painter: _RecordSleeve(swatches[index]));
    return Semantics(
        image: true,
        label: '$title cover art',
        child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: coverUrl.isEmpty
                ? fallback
                : Image.network(coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback)));
  }
}

class _RecordSleeve extends CustomPainter {
  const _RecordSleeve(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final center = Offset(size.width * .62, size.height * .53);
    final radius = size.shortestSide * .38;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF211B30));
    for (var i = 2; i < 8; i++) {
      canvas.drawCircle(
          center,
          radius * i / 8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7
            ..color = color.withValues(alpha: .25));
    }
    canvas.drawCircle(center, radius * .25, Paint()..color = color);
    canvas.drawCircle(
        center, radius * .05, Paint()..color = const Color(0xFF211B30));
    final line = Paint()
      ..color = const Color(0xFFFAF6FF).withValues(alpha: .8)
      ..strokeWidth = size.shortestSide * .018
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * .13, size.height * .18),
        Offset(size.width * .35, size.height * .18), line);
    canvas.drawLine(Offset(size.width * .13, size.height * .25),
        Offset(size.width * .25, size.height * .25), line);
  }

  @override
  bool shouldRepaint(_RecordSleeve oldDelegate) => oldDelegate.color != color;
}
