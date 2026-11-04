import 'package:flutter/material.dart';

import '../../models/subtitle.dart';

/// 底部字幕叠加层
class SubtitleOverlay extends StatelessWidget {
  const SubtitleOverlay({
    super.key,
    required this.position,
    required this.cues,
    this.enabled = true,
  });

  final Duration position;
  final List<SubtitleCue> cues;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || cues.isEmpty) return const SizedBox.shrink();

    SubtitleCue? current;
    for (final c in cues) {
      if (c.contains(position)) {
        current = c;
        break;
      }
    }
    if (current == null) return const SizedBox.shrink();

    return Positioned(
      left: 24,
      right: 24,
      bottom: 72,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: Text(
            current.text,
            key: ValueKey(current.text),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w500,
              shadows: const [
                Shadow(blurRadius: 4, color: Colors.black87),
                Shadow(blurRadius: 8, color: Colors.black54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
