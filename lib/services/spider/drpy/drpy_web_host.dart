import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 基于 WebView 的 Drpy 宿主（兼容性更好，对标 BieCuiLe）
///
/// 使用前需在 Widget 树中挂载 [DrpyWebHostView]（可用 Offstage）。
class DrpyWebHost {
  DrpyWebHost._();
  static final DrpyWebHost instance = DrpyWebHost._();

  WebViewController? _controller;
  bool _ready = false;
  final _readyCompleter = Completer<void>();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 25),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  ));

  dynamic lastResult;
  final Map<String, Completer<String>> _pending = {};

  bool get isReady => _ready;

  Future<void> get ready => _readyCompleter.future;

  /// 由 [DrpyWebHostView] 在 onWebViewCreated 后调用
  Future<void> attach(WebViewController controller) async {
    _controller = controller;
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'DrpyBridge',
        onMessageReceived: _onBridgeMessage,
      );

    // 空白页 + 注入 host
    await controller.loadHtmlString(
      '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body></body></html>',
    );

    final hostJs = await rootBundle.loadString('assets/js/drpy_webview_host.js');
    await controller.runJavaScript(hostJs);

    // 等待 host ready
    for (var i = 0; i < 20; i++) {
      final flag = await controller.runJavaScriptReturningResult(
        'window.__hostReady === true',
      );
      if (flag == true || flag.toString() == 'true') {
        _ready = true;
        if (!_readyCompleter.isCompleted) _readyCompleter.complete();
        debugPrint('[DrpyWebHost] ready');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _ready = true;
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    try {
      final map = jsonDecode(message.message) as Map<String, dynamic>;
      final action = map['action']?.toString();
      if (action == 'request') {
        _handleRequest(map);
      } else if (action == 'setResult') {
        lastResult = map['data'];
      }
    } catch (e) {
      debugPrint('[DrpyWebHost] bridge error: $e');
    }
  }

  Future<void> _handleRequest(Map<String, dynamic> map) async {
    final id = map['id']?.toString() ?? '';
    final url = map['url']?.toString() ?? '';
    final method = (map['method']?.toString() ?? 'GET').toUpperCase();
    final headers = Map<String, dynamic>.from(map['headers'] as Map? ?? {});
    final body = map['body'];
    final timeout = map['timeout'] as int? ?? 15000;

    try {
      final resp = await _dio.request(
        url,
        data: body,
        options: Options(
          method: method,
          headers: headers.isNotEmpty ? headers : null,
          sendTimeout: Duration(milliseconds: timeout),
          receiveTimeout: Duration(milliseconds: timeout),
          responseType: ResponseType.plain,
        ),
      );
      final bodyStr = resp.data?.toString() ?? '';
      await _controller?.runJavaScript(
        'window.__nativeResolve(${jsonEncode(id)}, ${jsonEncode(bodyStr)}, null);',
      );
    } catch (e) {
      await _controller?.runJavaScript(
        'window.__nativeResolve(${jsonEncode(id)}, null, ${jsonEncode(e.toString())});',
      );
    }
  }

  Future<void> loadRule(String ruleSource) async {
    await ready;
    lastResult = null;
    final ctrl = _controller;
    if (ctrl == null) throw Exception('WebView host not attached');

    await ctrl.runJavaScript('''
      var rule = {};
      var HOST = '';
      var MY_URL = '';
      var KEY = '';
      window.__lastResult = null;
    ''');
    // 规则可能很大，直接 evaluate
    await ctrl.runJavaScript(ruleSource);
  }

  /// 调用规则函数，返回解析后的 JSON
  Future<dynamic> call(String fnName, List<dynamic> args) async {
    await ready;
    final ctrl = _controller;
    if (ctrl == null) throw Exception('WebView host not attached');

    lastResult = null;
    final argsJson = jsonEncode(args);

    // 支持 async 函数
    final code = '''
      (async function(){
        try {
          var fn = null;
          if (typeof $fnName === 'function') fn = $fnName;
          else if (typeof rule !== 'undefined' && typeof rule.$fnName === 'function') fn = rule.$fnName.bind(rule);
          if (!fn) return JSON.stringify(null);
          var r = fn.apply(null, $argsJson);
          if (r && typeof r.then === 'function') r = await r;
          window.__lastResult = r;
          if (typeof r === 'undefined') return JSON.stringify(null);
          return JSON.stringify(r);
        } catch(e) {
          return JSON.stringify({__error: String(e), stack: e.stack || ''});
        }
      })()
    ''';

    final raw = await ctrl.runJavaScriptReturningResult(code);
    // runJavaScriptReturningResult 对 Promise 在部分版本会直接给结果字符串
    String resultStr = raw?.toString() ?? 'null';

    // 去掉多余引号（部分 WebView 返回带引号的 JSON 字符串）
    if (resultStr.startsWith('"') && resultStr.endsWith('"')) {
      try {
        resultStr = jsonDecode(resultStr) as String;
      } catch (_) {}
    }

    // 若仍是 Promise 占位，轮询 __lastResult
    if (resultStr.contains('[object Promise]') || resultStr == 'null') {
      for (var i = 0; i < 40; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        final lr = await ctrl.runJavaScriptReturningResult(
          'JSON.stringify(window.__lastResult)',
        );
        var s = lr?.toString() ?? 'null';
        if (s.startsWith('"') && s.endsWith('"')) {
          try {
            s = jsonDecode(s) as String;
          } catch (_) {}
        }
        if (s != 'null' && !s.contains('[object Promise]')) {
          resultStr = s;
          break;
        }
      }
    }

    if (resultStr == 'null' || resultStr.isEmpty) {
      return lastResult;
    }

    try {
      final decoded = jsonDecode(resultStr);
      if (decoded is Map && decoded.containsKey('__error')) {
        debugPrint('DrpyWeb rule error ($fnName): ${decoded['__error']}');
        return lastResult;
      }
      lastResult = decoded;
      return decoded;
    } catch (_) {
      return resultStr;
    }
  }

  Future<void> reset() async {
    lastResult = null;
    _pending.clear();
  }
}
