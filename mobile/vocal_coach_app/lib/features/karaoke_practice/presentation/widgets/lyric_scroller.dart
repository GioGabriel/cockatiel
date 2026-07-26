import 'package:flutter/material.dart';
import '../karaoke_singing_page.dart';

class LyricScroller extends StatefulWidget {
  const LyricScroller({
    super.key,
    required this.lyrics,
    required this.currentPosition,
  });

  final List<LyricLine> lyrics;
  final Duration currentPosition;

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
      _scrollController.animateTo(
        newIndex * 50.0, // Assuming 50.0 height per item
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return const Center(
        child: Text(
          "No lyrics found.",
          style: TextStyle(color: Colors.white54, fontSize: 18),
        ),
      );
    }

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.2, 0.8, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 150.0), // Padding to keep lyrics centered
        itemCount: widget.lyrics.length,
        itemExtent: 50.0,
        itemBuilder: (context, index) {
          final isCurrent = index == _currentIndex;
          final line = widget.lyrics[index];

          return Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: isCurrent ? 24.0 : 18.0,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? Colors.white : Colors.white38,
                shadows: isCurrent
                    ? [
                        const Shadow(
                          blurRadius: 10.0,
                          color: Colors.pinkAccent,
                          offset: Offset(0, 0),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                line.text,
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
