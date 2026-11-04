import 'package:flutter/material.dart';

/// 右上角角标（高清 / 更新 / 线路等）
class CornerBadge extends StatelessWidget {
  const CornerBadge({
    super.key,
    required this.text,
    this.color,
  });

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final bg = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.92),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 根据 remarks 推断角标颜色
Color badgeColorFor(String? remarks, ColorScheme scheme) {
  final r = (remarks ?? '').toLowerCase();
  if (r.contains('4k') || r.contains('高清') || r.contains('蓝光')) {
    return const Color(0xFF0984E3);
  }
  if (r.contains('更新') || r.contains('新')) {
    return const Color(0xFFE17055);
  }
  if (r.contains('完结') || r.contains('全')) {
    return const Color(0xFF00B894);
  }
  return scheme.primary;
}
