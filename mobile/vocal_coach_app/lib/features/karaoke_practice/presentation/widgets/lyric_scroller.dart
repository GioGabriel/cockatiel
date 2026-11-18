import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/song_content_parser.dart';

class LyricScroller extends StatefulWidget {
  const LyricScroller({
    super.key,
    required this.lyrics,
    required this.currentPosition,
    this.emptyMessage,
    this.plainLyrics,
  });

  final List<LyricLine> lyrics;
  final Duration currentPosition;
  final String? emptyMessage;
  final String? plainLyrics;

  @override
  State<LyricScroller> createState() => _LyricScrollerState();
}

class _LyricScrollerState extends State<LyricScroller> {
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0;
  List<double> _lineOffsets = const [];

  @override
  void initState() {
    super.initState();
    _updateCurrentIndex();
  }

  @override
  void didUpdateWidget(LyricScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != oldWidget.currentPosition ||
        widget.lyrics != oldWidget.lyrics) {
      _updateCurrentIndex();
    }
  }

  void _updateCurrentIndex() {
    if (widget.lyrics.isEmpty) return;

    int newIndex = -1;
    for (int i = 0; i < widget.lyrics.length; i++) {
      if (widget.currentPosition >= widget.lyrics[i].time) {
        newIndex = i;
      } else {
        break;
      }
    }

    if (newIndex != -1 && newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
      // Extents depend on viewport width and the user's text size. Wait for
      // layout to recalculate them before bringing the active line into view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_scrollController.hasClients ||
            newIndex >= _lineOffsets.length) {
          return;
        }
        final target = _lineOffsets[newIndex]
            .clamp(0.0, _scrollController.position.maxScrollExtent);
        if (MediaQuery.disableAnimationsOf(context)) {
          _scrollController.jumpTo(target);
        } else {
          _scrollController.animateTo(target,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.lyrics.isEmpty) {
      final plainLyrics = widget.plainLyrics?.trim();
      if (plainLyrics != null && plainLyrics.isNotEmpty) {
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Lyrics • scroll at your own pace',
                style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(plainLyrics,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium),
            ),
          ),
        ]);
      }
      return Center(
        child: Text(
          widget.emptyMessage ?? 'Lyrics are unavailable for this song.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final activeStyle =
          (theme.textTheme.headlineSmall ?? const TextStyle(fontSize: 24))
              .copyWith(fontWeight: FontWeight.w700);
      final heights = <double>[];
      _lineOffsets = [];
      var offset = 0.0;
      for (final line in widget.lyrics) {
        _lineOffsets.add(offset);
        final painter = TextPainter(
            text: TextSpan(text: line.text, style: activeStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context))
          ..layout(maxWidth: math.max(1, constraints.maxWidth - 32));
        final height = math.max(58.0, painter.height + 24);
        painter.dispose();
        heights.add(height);
        offset += height;
      }
      final padding =
          math.max(0.0, (constraints.maxHeight - heights.first) / 2);
      return ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(vertical: padding, horizontal: 16),
        itemCount: widget.lyrics.length,
        itemExtentBuilder: (index, _) => heights[index],
        itemBuilder: (context, index) {
          final isCurrent = index == _currentIndex;
          final line = widget.lyrics[index];
          return Semantics(
              liveRegion: isCurrent,
              label: isCurrent ? 'Current lyric: ${line.text}' : line.text,
              child: Center(
                  child: AnimatedDefaultTextStyle(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                style: activeStyle.copyWith(
                    color: isCurrent
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: .65),
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500),
                child: Text(line.text, textAlign: TextAlign.center),
              )));
        },
      );
    });
  }
}
