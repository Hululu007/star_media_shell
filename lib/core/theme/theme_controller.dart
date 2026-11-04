import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// 主题状态
@immutable
class ThemeState {
  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.accentColor = AppColors.defaultAccent,
    this.fontSizeFactor = 1.0,
    this.liquidGlass = true,
    this.adaptiveColor = false,
  });

  final ThemeMode themeMode;
  final Color accentColor;
  final double fontSizeFactor; // 0.85 ~ 1.25
  final bool liquidGlass;
  final bool adaptiveColor; // 是否根据壁纸/海报提取强调色（后期实现）

  ThemeState copyWith({
    ThemeMode? themeMode,
    Color? accentColor,
    double? fontSizeFactor,
    bool? liquidGlass,
    bool? adaptiveColor,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      fontSizeFactor: fontSizeFactor ?? this.fontSizeFactor,
      liquidGlass: liquidGlass ?? this.liquidGlass,
      adaptiveColor: adaptiveColor ?? this.adaptiveColor,
    );
  }
}

/// 主题控制器
class ThemeController extends StateNotifier<ThemeState> {
  ThemeController() : super(const ThemeState()) {
    _load();
  }

  static const _keyThemeMode = 'theme_mode';
  static const _keyAccent = 'accent_color';
  static const _keyFontSize = 'font_size_factor';
  static const _keyLiquidGlass = 'liquid_glass';
  static const _keyAdaptive = 'adaptive_color';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final modeIndex = prefs.getInt(_keyThemeMode) ?? 0;
    final accentValue = prefs.getInt(_keyAccent);
    final fontSize = prefs.getDouble(_keyFontSize) ?? 1.0;
    final liquid = prefs.getBool(_keyLiquidGlass) ?? true;
    final adaptive = prefs.getBool(_keyAdaptive) ?? false;

    state = ThemeState(
      themeMode: ThemeMode.values[modeIndex.clamp(0, 2)],
      accentColor: accentValue != null ? Color(accentValue) : AppColors.defaultAccent,
      fontSizeFactor: fontSize.clamp(0.85, 1.25),
      liquidGlass: liquid,
      adaptiveColor: adaptive,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  Future<void> setAccentColor(Color color) async {
    state = state.copyWith(accentColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccent, color.value);
  }

  Future<void> setFontSizeFactor(double factor) async {
    final clamped = factor.clamp(0.85, 1.25);
    state = state.copyWith(fontSizeFactor: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, clamped);
  }

  Future<void> setLiquidGlass(bool enabled) async {
    state = state.copyWith(liquidGlass: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLiquidGlass, enabled);
  }

  Future<void> setAdaptiveColor(bool enabled) async {
    state = state.copyWith(adaptiveColor: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAdaptive, enabled);
  }

  /// 循环切换主题模式：系统 → 浅色 → 深色 → 系统
  void cycleThemeMode() {
    final next = switch (state.themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    setThemeMode(next);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeState>((ref) {
  return ThemeController();
});
