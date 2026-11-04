import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'theme_extensions.dart';

/// 应用主题工厂
class AppTheme {
  AppTheme._();

  static ThemeData light({
    required Color accent,
    double fontSizeFactor = 1.0,
    bool liquidGlass = true,
  }) {
    final colorScheme = ColorScheme.light(
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: accent.withOpacity(0.12),
      onPrimaryContainer: accent,
      secondary: accent.withOpacity(0.8),
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.lightTextTertiary.withOpacity(0.3),
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      accent: accent,
      fontSizeFactor: fontSizeFactor,
      liquidGlass: liquidGlass,
      background: AppColors.lightBackground,
      surface: AppColors.lightSurface,
      card: AppColors.lightCard,
      textPrimary: AppColors.lightTextPrimary,
      textSecondary: AppColors.lightTextSecondary,
      textTertiary: AppColors.lightTextTertiary,
    );
  }

  static ThemeData dark({
    required Color accent,
    double fontSizeFactor = 1.0,
    bool liquidGlass = true,
  }) {
    final colorScheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: accent.withOpacity(0.18),
      onPrimaryContainer: accent.withOpacity(0.9),
      secondary: accent.withOpacity(0.85),
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.darkTextTertiary.withOpacity(0.25),
    );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      accent: accent,
      fontSizeFactor: fontSizeFactor,
      liquidGlass: liquidGlass,
      background: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      card: AppColors.darkCard,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      textTertiary: AppColors.darkTextTertiary,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color accent,
    required double fontSizeFactor,
    required bool liquidGlass,
    required Color background,
    required Color surface,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
  }) {
    final isDark = brightness == Brightness.dark;

    // 使用系统默认中文字体 + Google Fonts 兜底（实际项目可换成 NotoSansSC 本地字体）
    final textTheme = GoogleFonts.notoSansScTextTheme(
      TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textTertiary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textTertiary,
        ),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: card,
      dividerColor: textTertiary.withOpacity(0.12),
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: liquidGlass ? Colors.transparent : surface,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
      ),

      // Card
      cardTheme: CardTheme(
        elevation: liquidGlass ? 0 : 1,
        color: liquidGlass
            ? (isDark
                ? AppColors.glassDark(opacity: 0.55)
                : AppColors.glassLight(opacity: 0.7))
            : card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: liquidGlass
              ? BorderSide(
                  color: isDark
                      ? AppColors.glassBorderDark
                      : AppColors.glassBorderLight,
                  width: 0.8,
                )
              : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textTertiary),
      ),

      // BottomNavigationBar / NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: liquidGlass
            ? (isDark
                ? AppColors.glassDark(opacity: 0.75)
                : AppColors.glassLight(opacity: 0.85))
            : surface,
        indicatorColor: accent.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelMedium?.copyWith(color: textTertiary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent, size: 24);
          }
          return IconThemeData(color: textTertiary, size: 24);
        }),
        height: 68,
        elevation: 0,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        selectedColor: accent.withOpacity(0.18),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide.none,
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: textTertiary.withOpacity(0.4),
      ),

      // Switch / Checkbox / Radio
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? Colors.grey.shade400 : Colors.grey.shade50;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return isDark ? Colors.grey.shade700 : Colors.grey.shade300;
        }),
      ),

      // 自定义扩展
      extensions: [
        AppThemeExtension(
          accent: accent,
          liquidGlass: liquidGlass,
          glassBackground: isDark
              ? AppColors.glassDark(opacity: 0.55)
              : AppColors.glassLight(opacity: 0.7),
          glassBorder: isDark
              ? AppColors.glassBorderDark
              : AppColors.glassBorderLight,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textTertiary: textTertiary,
          success: AppColors.success,
          warning: AppColors.warning,
          error: AppColors.error,
          info: AppColors.info,
        ),
      ],
    );
  }
}
