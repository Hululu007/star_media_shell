import 'package:flutter/material.dart';

/// 应用核心颜色定义（对标 BieCuiLe 的现代高颜值风格）
class AppColors {
  AppColors._();

  // ========== 基础中性色 ==========
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color pureBlack = Color(0xFF000000);

  // 浅色模式背景
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F2F5);
  static const Color lightCard = Color(0xFFFFFFFF);

  // 深色模式背景
  static const Color darkBackground = Color(0xFF0B0C0F);
  static const Color darkSurface = Color(0xFF15171C);
  static const Color darkSurfaceVariant = Color(0xFF1C1F26);
  static const Color darkCard = Color(0xFF1A1D24);

  // 文字
  static const Color lightTextPrimary = Color(0xFF1A1C1E);
  static const Color lightTextSecondary = Color(0xFF5F6368);
  static const Color lightTextTertiary = Color(0xFF9AA0A6);

  static const Color darkTextPrimary = Color(0xFFF1F3F4);
  static const Color darkTextSecondary = Color(0xFFB0B3B8);
  static const Color darkTextTertiary = Color(0xFF8A8D93);

  // ========== 预设强调色（可扩展） ==========
  static const List<Color> accentPresets = [
    Color(0xFF6C5CE7), // 靛蓝紫（默认）
    Color(0xFF00B894), // 薄荷绿
    Color(0xFFE17055), // 珊瑚橙
    Color(0xFF0984E3), // 天空蓝
    Color(0xFFFD79A8), // 樱花粉
    Color(0xFFFDCB6E), // 琥珀黄
    Color(0xFF00CEC9), // 青碧
    Color(0xFFA29BFE), // 淡紫
    Color(0xFFE84393), // 玫红
    Color(0xFF2D3436), // 石墨
  ];

  static const Color defaultAccent = Color(0xFF6C5CE7);

  // ========== 功能色 ==========
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color error = Color(0xFFE17055);
  static const Color info = Color(0xFF0984E3);

  // ========== 液态玻璃相关 ==========
  static Color glassLight({double opacity = 0.65}) =>
      Colors.white.withOpacity(opacity);

  static Color glassDark({double opacity = 0.45}) =>
      const Color(0xFF1C1F26).withOpacity(opacity);

  static Color glassBorderLight = Colors.white.withOpacity(0.25);
  static Color glassBorderDark = Colors.white.withOpacity(0.08);
}
