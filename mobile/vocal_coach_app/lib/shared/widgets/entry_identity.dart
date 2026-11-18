import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Identity used by the entry flows, without imposing a theme on the app.
class EntryWordmark extends StatelessWidget {
  const EntryWordmark({super.key});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.graphic_eq_rounded,
                size: 21, color: Theme.of(context).colorScheme.onPrimary)),
        const SizedBox(width: 10),
        Flexible(
            child: Text('cockatiel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.7))),
      ]);
}

/// Decorative, locally drawn artwork. It never represents a live measurement.
class EntryArtwork extends StatelessWidget {
  const EntryArtwork(
      {super.key = const ValueKey('voice-hero'),
      this.height = 220,
      this.variant = 0});
  final double height;
  final int variant;

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: switch (variant) {
          1 => 'Illustration of a pitch guide with a rising melody',
          2 => 'Illustration of a record with synchronized lyric lines',
          _ => 'Illustration of a microphone and flowing sound waves',
        },
        child: SizedBox(
            height: height,
            width: double.infinity,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: CustomPaint(painter: _EntryArtworkPainter(variant)))),
      );
}

class _EntryArtworkPainter extends CustomPainter {
  const _EntryArtworkPainter(this.variant);
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE5DCFF), Color(0xFFC5ADF1), Color(0xFFAE95DB)],
          ).createShader(bounds));
    if (variant == 1) {
      _paintPitchGuide(canvas, size);
      return;
    }
    if (variant == 2) {
      _paintSong(canvas, size);
      return;
    }
    final center = Offset(size.width * .52, size.height * .49);
    final unit = math.min(size.width, size.height) * .36;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.23);
    for (var i = 0; i < 5; i++) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero,
              width: unit * (2.6 + i * .42),
              height: unit * (1.3 + i * .35)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color =
                const Color(0xFF6D499A).withValues(alpha: .11 + i * .025));
    }
    canvas.restore();
    final wave = Path();
    for (var x = 0.0; x <= size.width; x += 2) {
      final t = x / size.width;
      final envelope = math.sin(t * math.pi);
      final y = center.dy +
          math.sin(t * math.pi * (6 + variant * 2)) * unit * .32 * envelope;
      if (x == 0) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    canvas.drawPath(
        wave,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFAF6FF).withValues(alpha: .8));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(.2);
    final mic = Rect.fromCenter(
        center: Offset(0, -unit * .15), width: unit * .68, height: unit * 1.2);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(unit * .12, unit * .94),
            width: unit * 1.1,
            height: unit * .17),
        Paint()
          ..color = const Color(0x22402C60)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            mic.shift(const Offset(5, 7)), Radius.circular(unit)),
        Paint()
          ..color = const Color(0x3350377C)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawRRect(
        RRect.fromRectAndRadius(mic, Radius.circular(unit)),
        Paint()
          ..shader = const LinearGradient(colors: [
            Color(0xFF30233F),
            Color(0xFF665379),
            Color(0xFF241A32),
            Color(0xFF49345F)
          ]).createShader(mic));
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
        mic.deflate(unit * .06), Radius.circular(unit)));
    for (var i = 0; i < 12; i++) {
      final y = mic.top + unit * .13 + i * unit * .064;
      canvas.drawLine(
          Offset(mic.left + unit * .1, y),
          Offset(mic.right - unit * .1, y),
          Paint()
            ..strokeWidth = 1.4
            ..color = const Color(0xFFB29CC9).withValues(alpha: .48));
    }
    canvas.restore();
    final arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * .065
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF493360);
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(0, unit * .06),
            width: unit * 1.02,
            height: unit * 1.25),
        0,
        math.pi,
        false,
        arm);
    canvas.drawLine(Offset(0, unit * .7), Offset(0, unit * .94), arm);
    canvas.drawLine(
        Offset(-unit * .28, unit * .94), Offset(unit * .28, unit * .94), arm);
    canvas.drawCircle(Offset(0, unit * .3), unit * .035,
        Paint()..color = const Color(0xFFE1CEFF));
    canvas.restore();
    final sparkle = Offset(size.width * .2, size.height * .25);
    final star = Path()
      ..moveTo(sparkle.dx, sparkle.dy - 7)
      ..quadraticBezierTo(
          sparkle.dx + 1, sparkle.dy - 1, sparkle.dx + 7, sparkle.dy)
      ..quadraticBezierTo(
          sparkle.dx + 1, sparkle.dy + 1, sparkle.dx, sparkle.dy + 7)
      ..quadraticBezierTo(
          sparkle.dx - 1, sparkle.dy + 1, sparkle.dx - 7, sparkle.dy)
      ..quadraticBezierTo(
          sparkle.dx - 1, sparkle.dy - 1, sparkle.dx, sparkle.dy - 7);
    canvas.drawPath(star, Paint()..color = const Color(0xFFFAF6FF));
    canvas.drawCircle(Offset(size.width * .8, size.height * .73), 3,
        Paint()..color = const Color(0xFFFAF6FF));
  }

  void _paintPitchGuide(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 300);
    final panel = RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, 38, 324, 224), const Radius.circular(24));
    canvas.drawRRect(panel.shift(const Offset(0, 8)),
        Paint()..color = const Color(0x19503579));
    canvas.drawRRect(panel, Paint()..color = const Color(0xFF21182F));
    for (var row = 0; row < 5; row++) {
      final y = 90.0 + row * 30;
      canvas.drawLine(
          Offset(62, y),
          Offset(338, y),
          Paint()
            ..color = const Color(0xFF40324F)
            ..strokeWidth = 1);
    }
    const points = [
      Offset(76, 195),
      Offset(128, 165),
      Offset(180, 165),
      Offset(232, 135),
      Offset(284, 105),
      Offset(324, 105)
    ];
    final melody = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      melody.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
        melody,
        Paint()
          ..color = const Color(0xFFBEA1F4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round);
    for (final point in points) {
      canvas.drawCircle(point, 8, Paint()..color = const Color(0xFFE9DBFF));
      canvas.drawCircle(point, 3, Paint()..color = const Color(0xFF70509D));
    }
    canvas.drawCircle(points[3], 17, Paint()..color = const Color(0x33E9DBFF));
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(64 + i * 19, 59, 12, 4), const Radius.circular(2)),
          Paint()..color = const Color(0xFFAA8DD9));
    }
    canvas.restore();
  }

  void _paintSong(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 300);
    const center = Offset(167, 126);
    canvas.drawCircle(center + const Offset(3, 8), 91,
        Paint()..color = const Color(0x22503579));
    canvas.drawCircle(
        center,
        91,
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xFF4F3969), Color(0xFF20182C)])
              .createShader(const Rect.fromLTWH(76, 35, 182, 182)));
    for (var i = 0; i < 7; i++) {
      canvas.drawCircle(
          center,
          48 + i * 5,
          Paint()
            ..color = const Color(0xFF73598E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8);
    }
    canvas.drawCircle(center, 34, Paint()..color = const Color(0xFFBEA1F4));
    canvas.drawCircle(center, 7, Paint()..color = const Color(0xFF281C39));
    final card = RRect.fromRectAndRadius(
        const Rect.fromLTWH(135, 178, 210, 86), const Radius.circular(18));
    canvas.drawRRect(card.shift(const Offset(0, 6)),
        Paint()..color = const Color(0x19503579));
    canvas.drawRRect(card, Paint()..color = const Color(0xFFFAF6FF));
    final ink = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    for (var i = 0; i < 3; i++) {
      ink.color = i == 1 ? const Color(0xFF7954B3) : const Color(0xFFD9CEE9);
      canvas.drawLine(Offset(159, 200 + i * 21),
          Offset(i == 1 ? 306 : 274, 200 + i * 21), ink);
    }
    final note = Paint()
      ..color = const Color(0xFF604280)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(const Rect.fromLTWH(300, 79, 17, 12), note);
    canvas.drawLine(const Offset(315, 84), const Offset(315, 50), note);
    canvas.drawLine(const Offset(315, 50), const Offset(331, 55), note);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EntryArtworkPainter oldDelegate) =>
      variant != oldDelegate.variant;
}
