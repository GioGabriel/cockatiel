import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Reusable client-approved midnight, violet and rose composition.
class VoiceStageBackground extends StatelessWidget {
  const VoiceStageBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Material(
        color: Theme.of(context).scaffoldBackgroundColor, child: child);
  }
}

class StudioCard extends StatelessWidget {
  const StudioCard(
      {super.key,
      required this.child,
      this.accent = false,
      this.onTap,
      this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final bool accent;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
          decoration: BoxDecoration(
            color: accent ? null : theme.colorScheme.surface,
            gradient: accent
                ? const LinearGradient(
                    colors: [Color(0xFF3A2858), Color(0xFF251B3D)])
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: InkWell(
              onTap: onTap, child: Padding(padding: padding, child: child))),
    );
  }
}

/// Bundled microphone artwork, tinted to the studio palette. The vector
/// fallback keeps the entry flow usable even when asset decoding fails.
class VoiceHero extends StatelessWidget {
  const VoiceHero({super.key = const ValueKey('voice-hero'), this.size = 260});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'Cockatiel microphone surrounded by violet sound waves',
        child: SizedBox.square(
          dimension: size,
          child: ClipOval(
              child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const RadialGradient(
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.58, 1],
            ).createShader(bounds),
            child: ColorFiltered(
              colorFilter:
                  const ColorFilter.mode(Color(0xFFB46CE9), BlendMode.hue),
              child: Image.asset(
                'assets/images/auth_3d_elements.jpg',
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    CustomPaint(painter: _VoiceHeroPainter()),
              ),
            ),
          )),
        ),
      );
}

class _VoiceHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.39;
    final bounds = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x665F27BA), Color(0x002B165B)],
          ).createShader(bounds));
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero,
              width: r * 2.1,
              height: r * (1.48 + i * 0.08)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 0 ? 3 : 1.5
            ..shader = const SweepGradient(colors: [
              Color(0x00130426),
              Color(0xFFE6BAFF),
              Color(0xFF882AEF),
              Color(0xFFEF8AC8),
              Color(0x00130426)
            ]).createShader(bounds));
      canvas.restore();
    }
    final mic = RRect.fromRectAndRadius(
        Rect.fromLTWH(-r * .25, -r * .53, r * .5, r * .86),
        Radius.circular(r * .25));
    canvas.drawRRect(
        mic,
        Paint()
          ..shader = const LinearGradient(colors: [
            Color(0xFF422170),
            Color(0xFFE8D7FF),
            Color(0xFF7D45BE),
            Color(0xFF24133E)
          ]).createShader(mic.outerRect));
    final line = Paint()
      ..color = const Color(0xFFEBD9FF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(-r * .37, -r * .23, r * .74, r * .75), 0,
        math.pi, false, line);
    canvas.drawLine(Offset(0, r * .5), Offset(0, r * .7), line);
    canvas.drawLine(Offset(-r * .2, r * .7), Offset(r * .2, r * .7), line);
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(
          Offset(-r * .13, i * r * .1 - r * .13),
          Offset(r * .13, i * r * .1 - r * .13),
          Paint()
            ..color = const Color(0x884A246D)
            ..strokeWidth = 2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
