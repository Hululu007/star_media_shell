import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Python 运行时宿主（对标催壳 Chaquopy）
///
/// Channel: com.starmedia.shell/python
/// - loadScript(source, moduleName)
/// - call(moduleName, method, argsJson) → JSON string
/// - isAvailable
class PythonHost {
  PythonHost._();
  static final PythonHost instance = PythonHost._();

  static const _channel = MethodChannel('com.starmedia.shell/python');

  bool? _available;
  bool _useFallback = false;

  /// 是否有原生 Python（Chaquopy 等）
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _available = false;
      _useFallback = true;
      return false;
    }
    try {
      final v = await _channel.invokeMethod<bool>('isAvailable');
      _available = v ?? false;
    } catch (_) {
      _available = false;
    }
    _useFallback = !_available!;
    return _available!;
  }

  bool get useFallback => _useFallback;

  Future<void> loadScript({
    required String moduleName,
    required String source,
  }) async {
    if (!await isAvailable()) return;
    final ok = await _channel.invokeMethod<bool>('loadScript', {
      'module': moduleName,
      'source': source,
    });
    if (ok != true) {
      throw StateError('native loadScript returned false');
    }
  }

  Future<dynamic> call(
    String moduleName,
    String method,
    List<dynamic> args,
  ) async {
    if (!await isAvailable()) {
      throw StateError('Python runtime unavailable');
    }
    final raw = await _channel.invokeMethod<String>('call', {
      'module': moduleName,
      'method': method,
      'args': jsonEncode(args),
    });
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    return jsonDecode(raw);
  }
}
