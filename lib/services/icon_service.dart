import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 桌面图标定义
class AppIconDef {
  const AppIconDef({
    required this.key,
    required this.name,
    required this.color,
    this.description,
  });

  final String key;
  final String name;
  final int color; // 预览色
  final String? description;
}

const List<AppIconDef> kAppIcons = [
  AppIconDef(key: 'default_star', name: '星辰', color: 0xFF6C5CE7, description: '默认'),
  AppIconDef(key: 'blob_blue', name: '液态蓝', color: 0xFF0984E3),
  AppIconDef(key: 'blob_mint', name: '薄荷绿', color: 0xFF00B894),
  AppIconDef(key: 'blob_coral', name: '珊瑚橙', color: 0xFFE17055),
  AppIconDef(key: 'painter_cat', name: '画家猫', color: 0xFFFD79A8),
  AppIconDef(key: 'painter_penguin', name: '画家企鹅', color: 0xFF636E72),
  AppIconDef(key: 'line_minimal', name: '线框', color: 0xFF2D3436),
];

/// 多图标切换服务（Android activity-alias）
class IconService {
  static const _channel = MethodChannel('com.starmedia.shell/icon');
  static const _prefKey = 'app_icon_key';

  Future<String> getCurrentKey() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKey) ?? 'default_star';
    }
    try {
      final key = await _channel.invokeMethod<String>('getIcon');
      return key ?? 'default_star';
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKey) ?? 'default_star';
    }
  }

  Future<bool> setIcon(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, key);

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true; // 非 Android 仅记偏好
    }
    try {
      final ok = await _channel.invokeMethod<bool>('setIcon', key);
      return ok ?? false;
    } catch (e) {
      debugPrint('setIcon failed: $e');
      return false;
    }
  }

  Future<List<String>> listIcons() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return kAppIcons.map((e) => e.key).toList();
    }
    try {
      final list = await _channel.invokeMethod<List>('listIcons');
      return list?.map((e) => e.toString()).toList() ??
          kAppIcons.map((e) => e.key).toList();
    } catch (_) {
      return kAppIcons.map((e) => e.key).toList();
    }
  }
}

final iconServiceProvider = Provider<IconService>((ref) => IconService());

final currentIconProvider = FutureProvider<String>((ref) async {
  return ref.watch(iconServiceProvider).getCurrentKey();
});
