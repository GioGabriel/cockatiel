import 'package:flutter/material.dart';
import '../karaoke_singing_page.dart';

class LyricScroller extends StatefulWidget {
  const LyricScroller({
    super.key,
    required this.lyrics,
    required this.currentPosition,
    this.emptyMessage,
  });

  final List<LyricLine> lyrics;
  final Duration currentPosition;
  final String? emptyMessage;

  @override
  State<LyricScroller> createState() => _LyricScrollerState();
}

class _LyricScrollerState extends State<LyricScroller> {
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0;

  @override
  void didUpdateWidget(LyricScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != oldWidget.currentPosition) {
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
      // Scroll to the active line
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          newIndex * 58.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 150),
      itemCount: widget.lyrics.length,
      itemExtent: 58,
      itemBuilder: (context, index) {
        final isCurrent = index == _currentIndex;
        final line = widget.lyrics[index];
        final text = AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: (isCurrent
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleMedium)
                  ?.copyWith(
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ) ??
              TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
          child: Text(line.text, textAlign: TextAlign.center),
        );

        return Semantics(
          liveRegion: isCurrent,
          label: isCurrent ? 'Current lyric: ${line.text}' : line.text,
          child: Center(child: text),
        );
      },
    );
  }
}
