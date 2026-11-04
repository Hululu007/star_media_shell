import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 投屏 / 画中画骨架（对标催壳扩展位）
/// Android 端需实现 MethodChannel `com.starmedia.shell/cast`
class CastService {
  static const _channel = MethodChannel('com.starmedia.shell/cast');

  Future<bool> isPipSupported() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('isPipSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> enterPip() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('enterPip') ?? false;
    } catch (e) {
      debugPrint('enterPip: $e');
      return false;
    }
  }

  /// 投屏：目前返回未实现，预留协议
  Future<String> castUrl(String url, {Map<String, String>? headers}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'unsupported';
    }
    try {
      final r = await _channel.invokeMethod<String>('cast', {
        'url': url,
        'headers': headers ?? {},
      });
      return r ?? 'ok';
    } catch (e) {
      debugPrint('cast: $e');
      return 'error';
    }
  }
}

final castServiceProvider = Provider<CastService>((ref) => CastService());
