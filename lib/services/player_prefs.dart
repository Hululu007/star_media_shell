import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerPrefs {
  static const _kDanmaku = 'player_danmaku_on';
  static const _kSubtitle = 'player_subtitle_on';
  static const _kAutoNext = 'player_auto_next';
  static const _kOpacity = 'player_danmaku_opacity';
  static const _kSpeed = 'player_speed';

  bool danmakuOn = true;
  bool subtitleOn = true;
  bool autoNext = true;
  double danmakuOpacity = 0.9;
  double speed = 1.0;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    danmakuOn = p.getBool(_kDanmaku) ?? true;
    subtitleOn = p.getBool(_kSubtitle) ?? true;
    autoNext = p.getBool(_kAutoNext) ?? true;
    danmakuOpacity = p.getDouble(_kOpacity) ?? 0.9;
    speed = p.getDouble(_kSpeed) ?? 1.0;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDanmaku, danmakuOn);
    await p.setBool(_kSubtitle, subtitleOn);
    await p.setBool(_kAutoNext, autoNext);
    await p.setDouble(_kOpacity, danmakuOpacity);
    await p.setDouble(_kSpeed, speed);
  }
}

final playerPrefsProvider = FutureProvider<PlayerPrefs>((ref) async {
  final prefs = PlayerPrefs();
  await prefs.load();
  return prefs;
});
