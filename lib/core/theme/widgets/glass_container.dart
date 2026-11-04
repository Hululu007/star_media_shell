import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme_extensions.dart';

/// 液态玻璃容器（对标 BieCuiLe 的核心视觉）
///
/// 使用方式：
/// ```dart
/// GlassContainer(
///   child: Text('内容'),
/// )
/// ```
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blur = 18,
    this.opacity,
    this.padding,
    this.margin,
    this.borderWidth = 0.8,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final double? opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 如果用户关闭了液态玻璃，退化为普通卡片
    if (!theme.liquidGlass) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                child: child,
              )
            : child,
      );
    }

    final bgColor = opacity != null
        ? (isDark
            ? Colors.black.withOpacity(opacity!)
            : Colors.white.withOpacity(opacity!))
        : theme.glassBackground;

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: theme.glassBorder,
                    width: borderWidth,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 更轻量的玻璃卡片（用于列表项、小按钮等）
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.onTap,
    this.borderRadius = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: borderRadius,
      blur: 14,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }
}
