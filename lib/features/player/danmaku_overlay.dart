import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/danmaku.dart';

/// 弹幕叠加层（简化滚动实现）
class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({
    super.key,
    required this.position,
    required this.items,
    this.enabled = true,
    this.opacity = 0.9,
  });

  final Duration position;
  final List<DanmakuItem> items;
  final bool enabled;
  final double opacity;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  final List<_FlyingDanmaku> _flying = [];
  final Set<String> _emitted = {};
  Duration _lastPos = Duration.zero;
  late final AnimationController _ticker;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_onTick)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _flying.clear();
      return;
    }
    _spawn();
  }

  void _spawn() {
    if (!widget.enabled) return;
    final pos = widget.position;
    // 回退进度时清理已发射标记，允许弹幕再次出现
    if (pos + const Duration(seconds: 2) < _lastPos) {
      _emitted.clear();
      _flying.clear();
    }
    _lastPos = pos;
    for (final item in widget.items) {
      final key = '${item.time.inMilliseconds}_${item.text}';
      if (_emitted.contains(key)) continue;
      final diff = pos - item.time;
      // 在弹幕时间点附近触发（±300ms）
      if (diff.inMilliseconds >= 0 && diff.inMilliseconds < 350) {
        _emitted.add(key);
        final track = _rand.nextInt(8);
        _flying.add(_FlyingDanmaku(
          item: item,
          track: track,
          born: DateTime.now(),
          durationMs: 7000 + _rand.nextInt(2000),
        ));
      }
    }
    // 限制同屏数量
    if (_flying.length > 40) {
      _flying.removeRange(0, _flying.length - 40);
    }
  }

  void _onTick() {
    if (!mounted) return;
    final now = DateTime.now();
    _flying.removeWhere(
      (f) => now.difference(f.born).inMilliseconds > f.durationMs,
    );
    _spawn();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    final size = MediaQuery.sizeOf(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: widget.opacity,
          child: Stack(
            children: _flying.map((f) {
              final t = nowProgress(f);
              if (f.item.mode == DanmakuMode.top) {
                return Positioned(
                  top: 48.0 + f.track * 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _text(f.item),
                  ),
                );
              }
              if (f.item.mode == DanmakuMode.bottom) {
                return Positioned(
                  bottom: 100.0 + f.track * 4,
                  left: 0,
                  right: 0,
                  child: Center(child: _text(f.item)),
                );
              }
              // scroll: 从右到左
              final x = size.width * (1.05 - t * 1.25);
              final y = 40.0 + f.track * 28.0;
              return Positioned(
                left: x,
                top: y,
                child: _text(f.item),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  double nowProgress(_FlyingDanmaku f) {
    final ms = DateTime.now().difference(f.born).inMilliseconds;
    return (ms / f.durationMs).clamp(0.0, 1.0);
  }

  Widget _text(DanmakuItem item) {
    return Text(
      item.text,
      style: TextStyle(
        color: item.color,
        fontSize: item.fontSize,
        fontWeight: FontWeight.w600,
        shadows: const [
          Shadow(blurRadius: 2, color: Colors.black87),
          Shadow(blurRadius: 4, color: Colors.black54),
        ],
      ),
    );
  }
}

class _FlyingDanmaku {
  _FlyingDanmaku({
    required this.item,
    required this.track,
    required this.born,
    required this.durationMs,
  });

  final DanmakuItem item;
  final int track;
  final DateTime born;
  final int durationMs;
}
