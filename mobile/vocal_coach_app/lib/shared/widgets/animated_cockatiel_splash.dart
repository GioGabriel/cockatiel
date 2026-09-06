import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const double _artworkAspectRatio = 1122 / 1402;
const String _defaultFirstFrameAsset =
    'assets/images/cockatiel_splash_hero_v2.png';
const String _defaultVideoAsset = 'assets/videos/cockatiel_splash.mp4';
const List<String> _defaultFrameAssets = [
  _defaultFirstFrameAsset,
  'assets/images/cockatiel_splash_frame_1.png',
  'assets/images/cockatiel_splash_frame_2.png',
  'assets/images/cockatiel_splash_frame_3.png',
];

/// A short, deterministic brand entrance that works in Chrome and on Android.
///
/// The artwork is intentionally a normal Flutter asset instead of a web-only
/// animation. Flutter owns the motion, so the splash has the same lifecycle,
/// accessibility behavior, and test surface on every supported platform.
class AnimatedCockatielSplash extends StatefulWidget {
  const AnimatedCockatielSplash({
    super.key,
    this.assetPath = _defaultFirstFrameAsset,
    this.videoAssetPath = _defaultVideoAsset,
    this.enableVideo = true,
  });

  final String assetPath;
  final String videoAssetPath;
  final bool enableVideo;

  @override
  State<AnimatedCockatielSplash> createState() =>
      _AnimatedCockatielSplashState();
}

class _AnimatedCockatielSplashState extends State<AnimatedCockatielSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _flight;
  late final Animation<double> _noteReveal;
  late final Animation<double> _settle;
  VideoPlayerController? _videoController;
  bool _videoAttempted = false;
  bool _videoInitializationComplete = false;
  bool _videoReady = false;
  bool _motionDisabled = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      // This is a brand entrance, not a loading indicator. It must finish so
      // startup can hand control back to the auth gate without a live ticker.
      duration: const Duration(milliseconds: 2200),
    );
    _flight = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
    );
    _noteReveal = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.14, 0.78, curve: Curves.easeOutCubic),
    );
    _settle = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.58, 1, curve: Curves.easeInOutCubic),
    );
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motionDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (motionDisabled != _motionDisabled) {
      _motionDisabled = motionDisabled;
      if (motionDisabled) {
        _animationController
          ..stop()
          ..value = 1;
        final videoController = _videoController;
        if (videoController != null && _videoReady) {
          unawaited(_freezeVideo(videoController));
        }
      } else if (_videoReady) {
        final videoController = _videoController;
        if (videoController != null) {
          unawaited(videoController.play());
        }
      } else if (!_animationController.isCompleted) {
        _animationController.forward();
      }
    }

    if (!_videoAttempted && widget.enableVideo && !_motionDisabled) {
      _videoAttempted = true;
      unawaited(_initializeVideo());
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    final videoController = _videoController;
    _videoController = null;
    if (videoController != null && _videoInitializationComplete) {
      unawaited(_disposeVideoController(videoController));
    }
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.asset(widget.videoAssetPath);
    _videoController = controller;
    var initializationSucceeded = false;
    try {
      await controller.initialize();
      initializationSucceeded = true;
      _videoInitializationComplete = true;
      await controller.setLooping(false);
      // The supplied splash includes a short audio bed. Native platforms can
      // start it with the splash animation; browser autoplay policy is
      // handled by web/index.html with an explicit sound affordance.
      await controller.setVolume(1);
      if (!mounted) {
        unawaited(_disposeVideoController(controller));
        return;
      }

      if (_motionDisabled) {
        await _freezeVideo(controller);
      } else {
        await controller.play();
      }
      if (!mounted) {
        unawaited(_disposeVideoController(controller));
        return;
      }
      setState(() {
        _videoReady = true;
      });
    } catch (_) {
      // The animated artwork is the intentional fallback for unsupported
      // codecs, missing assets, autoplay restrictions, or plugin failures.
      if (mounted) {
        setState(() {
          _videoReady = false;
        });
      }
      _videoInitializationComplete = true;
      if (initializationSucceeded) {
        unawaited(_disposeVideoController(controller));
      } else if (identical(_videoController, controller)) {
        // video_player may leave its creation future incomplete when the
        // platform backend is unavailable. Do not await disposal in that
        // state; there is no platform player to reclaim.
        _videoController = null;
      }
    }
  }

  Future<void> _freezeVideo(VideoPlayerController controller) async {
    try {
      await controller.pause();
      await controller.seekTo(controller.value.duration);
    } catch (_) {
      // Reduced-motion fallback must remain usable even if seeking is not
      // supported by a platform video backend.
    }
  }

  Future<void> _disposeVideoController(
    VideoPlayerController controller,
  ) async {
    try {
      await controller.dispose();
    } catch (_) {
      // Disposal is best effort when a platform backend shuts down during
      // startup or route teardown.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showVideo =
        _videoReady && !_motionDisabled && _videoController != null;

    return Semantics(
      container: true,
      label: 'Preparing Cockatiel vocal coaching',
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showVideo) _FullBleedSplashVideo(controller: _videoController!),
            if (!showVideo)
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const reservedForWordmark = 92.0;
                    final artworkSize = _containSize(
                      Size(
                        constraints.maxWidth,
                        math.max(
                          0,
                          constraints.maxHeight - reservedForWordmark,
                        ),
                      ),
                    );
                    return AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, _) {
                        final progress =
                            _motionDisabled ? 1.0 : _animationController.value;
                        final flight = _motionDisabled ? 1.0 : _flight.value;
                        final noteReveal =
                            _motionDisabled ? 1.0 : _noteReveal.value;
                        final settle = _motionDisabled ? 1.0 : _settle.value;
                        final frame = _frameFor(progress);
                        final opacity = _opacity(flight, 0, 0.18);
                        final scale = _lerp(0.96, 1, flight);
                        final offset = Offset(
                          _lerp(-artworkSize.width * 0.18, 0, flight),
                          _lerp(artworkSize.height * 0.04, 0, flight) -
                              math.sin(flight * math.pi) *
                                  artworkSize.height *
                                  0.03,
                        );
                        final rotation = _lerp(-0.025, 0, flight) +
                            math.sin(settle * math.pi) * 0.006;

                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: artworkSize.width,
                                height: artworkSize.height,
                                child: Transform.translate(
                                  offset: offset,
                                  child: Transform.rotate(
                                    angle: rotation,
                                    child: Transform.scale(
                                      scale: scale,
                                      child: Opacity(
                                        opacity: opacity,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            RepaintBoundary(
                                              child: _SplashArtwork(
                                                assetPath: widget.assetPath,
                                                frame: frame,
                                                primaryColor:
                                                    colorScheme.primary,
                                                secondaryColor:
                                                    colorScheme.secondary,
                                              ),
                                            ),
                                            IgnorePointer(
                                              child: CustomPaint(
                                                key: const ValueKey(
                                                  'cockatiel-splash-animation-layer',
                                                ),
                                                painter:
                                                    _SplashAnimationPainter(
                                                  entranceProgress: flight,
                                                  noteProgress: noteReveal,
                                                  settleProgress: settle,
                                                  animationProgress: progress,
                                                  primaryColor:
                                                      colorScheme.primary,
                                                  secondaryColor:
                                                      colorScheme.secondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Opacity(
                                opacity: _opacity(progress, 0.46, 0.78),
                                child: Text(
                                  'Cockatiel',
                                  key: const ValueKey(
                                      'cockatiel-splash-wordmark'),
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Size _containSize(Size available) {
    var width = available.width;
    var height = width / _artworkAspectRatio;
    if (height > available.height) {
      height = available.height;
      width = height * _artworkAspectRatio;
    }
    return Size(width, height);
  }

  int _frameFor(double progress) {
    if (_motionDisabled || progress >= 0.94) {
      return 2;
    }

    // Raised -> down -> recovery -> down gives the viewer unmistakable wing
    // articulation while remaining short enough for startup.
    const sequence = <int>[0, 1, 2, 3, 2, 1, 2];
    final index = (progress * sequence.length).floor().clamp(
          0,
          sequence.length - 1,
        );
    return sequence[index];
  }

  double _opacity(double progress, double start, double end) {
    if (progress <= start) {
      return 0;
    }
    if (progress >= end) {
      return 1;
    }
    return Curves.easeOut.transform((progress - start) / (end - start));
  }

  double _lerp(double begin, double end, double progress) {
    return begin + ((end - begin) * progress.clamp(0, 1));
  }
}

class _FullBleedSplashVideo extends StatelessWidget {
  const _FullBleedSplashVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final videoSize = controller.value.size;
    if (videoSize.width <= 0 || videoSize.height <= 0) {
      return const SizedBox.expand();
    }
    final viewportSize = MediaQuery.sizeOf(context);
    final viewportAspectRatio = viewportSize.height == 0
        ? 0.0
        : viewportSize.width / viewportSize.height;
    final fit = viewportAspectRatio >= 0.75 ? BoxFit.contain : BoxFit.cover;

    return Semantics(
      container: true,
      label: 'Cockatiel animated splash',
      child: ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            // Portrait phone screens get edge-to-edge coverage. Wide desktop
            // and tablet layouts preserve the complete portrait video.
            fit: fit,
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: videoSize.width,
              height: videoSize.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashAnimationPainter extends CustomPainter {
  const _SplashAnimationPainter({
    required this.entranceProgress,
    required this.noteProgress,
    required this.settleProgress,
    required this.animationProgress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final double entranceProgress;
  final double noteProgress;
  final double settleProgress;
  final double animationProgress;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Every accent is derived from the same finite progress value. Nothing in
    // this painter repeats after the entrance has settled.
    final phase = animationProgress * math.pi * 4;
    _drawFlightTrails(canvas, size);
    _drawNotes(canvas, size, phase);
    _drawMicrophonePulse(canvas, size);
    _drawResponsiveWaveform(canvas, size, phase);
  }

  void _drawFlightTrails(Canvas canvas, Size size) {
    final trailProgress = _fadeOut(entranceProgress, 0.72, 0.98);
    final trailPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.16 * trailProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.0018
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < 3; index++) {
      final path = Path()
        ..moveTo(size.width * (0.08 + index * 0.025), size.height * 0.68)
        ..quadraticBezierTo(
          size.width * 0.31,
          size.height * (0.58 - index * 0.018),
          size.width * 0.58,
          size.height * (0.45 + index * 0.02),
        );
      canvas.drawPath(path, trailPaint);
    }
  }

  void _drawNotes(Canvas canvas, Size size, double phase) {
    final notePaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.0022
      ..strokeCap = StrokeCap.round;
    final origin = Offset(size.width * 0.57, size.height * 0.35);
    final noteOffsets = <Offset>[
      const Offset(0, 0),
      const Offset(0.11, -0.07),
      const Offset(0.2, 0.02),
    ];

    for (var index = 0; index < noteOffsets.length; index++) {
      final launchProgress = noteProgress - (index * 0.16);
      if (launchProgress <= 0) {
        continue;
      }
      final launch = launchProgress.clamp(0.0, 1.0).toDouble();
      final lift = Curves.easeOutCubic.transform(launch);
      final fadeIn = (launchProgress / 0.16).clamp(0.0, 1.0).toDouble();
      final fadeOut = _fadeOut(noteProgress, 0.72, 1);
      final fade = fadeIn * fadeOut;
      final position = origin +
          Offset(
            size.width * noteOffsets[index].dx +
                math.sin(phase + index) * size.width * 0.012,
            size.height * noteOffsets[index].dy - size.height * 0.16 * lift,
          );
      _drawNote(
        canvas,
        size,
        position,
        notePaint
          ..color = secondaryColor.withValues(
            alpha: 0.62 * noteProgress * fade,
          ),
        flipped: index.isOdd,
      );
    }
  }

  void _drawMicrophonePulse(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.71, size.height * 0.58);
    final pulseProgress =
        ((animationProgress - 0.48) / 0.38).clamp(0.0, 1.0).toDouble();
    for (var index = 0; index < 2; index++) {
      final ringProgress =
          (pulseProgress - index * 0.22).clamp(0.0, 1.0).toDouble();
      final radius = size.width * (0.025 + ringProgress * 0.095);
      final pulsePaint = Paint()
        ..color = primaryColor.withValues(
          alpha: 0.13 * (1 - ringProgress) * settleProgress,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.002;
      canvas.drawCircle(center, radius, pulsePaint);
    }
  }

  void _drawResponsiveWaveform(Canvas canvas, Size size, double phase) {
    final waveformOpacity = _fadeOut(animationProgress, 0.62, 1);
    final waveformPaint = Paint()
      ..color = primaryColor.withValues(
        alpha: 0.14 * settleProgress * waveformOpacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.0018
      ..strokeCap = StrokeCap.round;
    final waveform = Path();
    final baseline = size.height * 0.68;
    for (var index = 0; index <= 40; index++) {
      final x = size.width * index / 40;
      final pulse = math.sin(index * 0.85 + phase);
      final amplitude = size.height * (0.008 + pulse.abs() * 0.025);
      final y = baseline + math.sin(index * 0.72 + phase) * amplitude;
      if (index == 0) {
        waveform.moveTo(x, y);
      } else {
        waveform.lineTo(x, y);
      }
    }
    canvas.drawPath(waveform, waveformPaint);
  }

  void _drawNote(
    Canvas canvas,
    Size size,
    Offset origin,
    Paint paint, {
    required bool flipped,
  }) {
    final stemDirection = flipped ? -1.0 : 1.0;
    final noteWidth = math.max(10.0, size.width * 0.016);
    final noteHeight = noteWidth * 0.68;
    final stemLength = math.max(18.0, size.width * 0.026);
    final beamLength = math.max(8.0, size.width * 0.014);
    final stemTop = origin.translate(0, -stemLength * stemDirection);
    canvas.drawOval(
      Rect.fromCenter(center: origin, width: noteWidth, height: noteHeight),
      paint,
    );
    canvas.drawLine(origin, stemTop, paint);
    canvas.drawLine(
      stemTop,
      stemTop.translate(beamLength * stemDirection, 7 * stemDirection),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashAnimationPainter oldDelegate) {
    return oldDelegate.entranceProgress != entranceProgress ||
        oldDelegate.noteProgress != noteProgress ||
        oldDelegate.settleProgress != settleProgress ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }

  double _fadeOut(double progress, double start, double end) {
    if (progress <= start) {
      return 1;
    }
    if (progress >= end) {
      return 0;
    }
    return 1 - Curves.easeIn.transform((progress - start) / (end - start));
  }
}

class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork({
    required this.assetPath,
    required this.frame,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final String assetPath;
  final int frame;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    final frameAsset = assetPath == _defaultFirstFrameAsset
        ? _defaultFrameAssets[frame]
        : assetPath;

    return Semantics(
      container: true,
      label: 'Cockatiel vocal coaching artwork',
      image: true,
      excludeSemantics: true,
      child: Image.asset(
        key: const ValueKey('cockatiel-splash-artwork'),
        frameAsset,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return SizedBox.expand(
            child: CustomPaint(
              key: const ValueKey('cockatiel-splash-artwork-fallback'),
              painter: _SplashFallbackPainter(
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SplashFallbackPainter extends CustomPainter {
  const _SplashFallbackPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.46, size.height * 0.42);
    final bodyPaint = Paint()..color = secondaryColor.withValues(alpha: 0.82);
    final wingPaint = Paint()..color = primaryColor.withValues(alpha: 0.75);
    final linePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, size.height * 0.08),
        width: size.width * 0.3,
        height: size.height * 0.38,
      ),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-size.width * 0.06, -size.height * 0.08),
        width: size.width * 0.27,
        height: size.height * 0.2,
      ),
      bodyPaint,
    );

    final wing = Path()
      ..moveTo(center.dx - size.width * 0.06, center.dy)
      ..quadraticBezierTo(
        center.dx - size.width * 0.4,
        center.dy - size.height * 0.22,
        center.dx - size.width * 0.26,
        center.dy + size.height * 0.24,
      )
      ..close();
    canvas.drawPath(wing, wingPaint);

    canvas.drawCircle(
      center.translate(size.width * 0.11, -size.height * 0.1),
      size.width * 0.015,
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.68),
      Offset(size.width * 0.88, size.height * 0.68),
      linePaint,
    );
    for (var index = 0; index < 22; index++) {
      final x = size.width * index / 21;
      final height = size.height * (0.012 + (index % 3) * 0.014);
      canvas.drawLine(
        Offset(x, size.height * 0.68 - height),
        Offset(x, size.height * 0.68 + height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashFallbackPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
