import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';

/// Drpy2 宿主环境
///
/// 在 QuickJS 中注入 TVBox / drpy2 规则常用的全局函数：
/// - request / post / fetch
/// - pdfh / pdfa / pd（简化版，基于正则/字符串）
/// - setResult / setHome / joinUrl 等
///
/// 真实生产环境可把 pdfh/pdfa 换成更完整的 HTML 解析（html 包或原生）。
class DrpyHost {
  DrpyHost() {
    _runtime = getJavascriptRuntime();
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    ));
    _setupHost();
  }

  late final JavascriptRuntime _runtime;
  late final Dio _dio;

  /// 最近一次规则 setResult 的结果
  dynamic lastResult;

  JavascriptRuntime get runtime => _runtime;

  void _setupHost() {
    // ---- 网络请求 ----
    _runtime.onMessage('native_request', (args) async {
      try {
        final map = args is Map ? args : jsonDecode(args.toString()) as Map;
        final url = map['url']?.toString() ?? '';
        final method = (map['method']?.toString() ?? 'GET').toUpperCase();
        final headers = Map<String, dynamic>.from(map['headers'] ?? {});
        final body = map['body'];
        final timeout = map['timeout'] as int? ?? 15000;

        final options = Options(
          method: method,
          headers: headers.isNotEmpty ? headers : null,
          sendTimeout: Duration(milliseconds: timeout),
          receiveTimeout: Duration(milliseconds: timeout),
          responseType: ResponseType.plain,
        );

        final resp = await _dio.request(
          url,
          data: body,
          options: options,
        );

        return jsonEncode({
          'code': resp.statusCode ?? 0,
          'body': resp.data?.toString() ?? '',
          'headers': resp.headers.map,
        });
      } catch (e) {
        return jsonEncode({'code': -1, 'body': '', 'error': e.toString()});
      }
    });

    // ---- 把结果回传给 Dart ----
    _runtime.onMessage('native_setResult', (args) {
      try {
        lastResult = args is String ? jsonDecode(args) : args;
      } catch (_) {
        lastResult = args;
      }
      return null;
    });

    // 注入宿主 JS
    _runtime.evaluate(_hostJs);
  }

  /// 执行一段 JS 并返回字符串结果
  String evaluate(String code) {
    final result = _runtime.evaluate(code);
    if (result.isError) {
      throw Exception('JS Error: ${result.stringResult}');
    }
    return result.stringResult;
  }

  /// 异步执行（用于带 request 的规则）
  Future<String> evaluateAsync(String code) async {
    final promise = _runtime.evaluate(code);
    if (promise.isError) {
      throw Exception('JS Error: ${promise.stringResult}');
    }
    // flutter_js 对 Promise 的处理
    final handled = await _runtime.handlePromise(promise);
    if (handled.isError) {
      throw Exception('JS Promise Error: ${handled.stringResult}');
    }
    return handled.stringResult;
  }

  /// 加载规则源码并执行初始化
  Future<void> loadRule(String ruleSource) async {
    // 清理上次结果
    lastResult = null;
    // 规则通常是一个 JS 对象或函数集合
    evaluate('''
      var rule = {};
      var HOST = '';
      var MY_URL = '';
      var MY_CATE = '';
      var MY_PAGE = 1;
      var KEY = '';
    ''');
    evaluate(ruleSource);
  }

  void dispose() {
    _runtime.dispose();
  }

  /// 宿主环境 JS（精简版，覆盖 drpy2 最常用 API）
  static const String _hostJs = r'''
// ===== 基础工具 =====
function print(msg) { console.log(String(msg)); }

function joinUrl(base, url) {
  if (!url) return base || '';
  if (/^https?:\/\//i.test(url)) return url;
  if (url.startsWith('//')) return 'https:' + url;
  if (!base) return url;
  try {
    var u = new URL(url, base);
    return u.href;
  } catch (e) {
    if (url.startsWith('/')) {
      var m = base.match(/^(https?:\/\/[^\/]+)/);
      return m ? m[1] + url : url;
    }
    return base.replace(/\/[^\/]*$/, '/') + url;
  }
}

function urljoin(base, url) { return joinUrl(base, url); }

// ===== 网络（同步风格，实际走 native 异步再回填）=====
// 为了兼容大量同步 request 写法，这里用一个简化队列 + 阻塞模拟。
// 真正生产建议规则侧改成 async，或使用完整 WebView Host。

var __reqCache = {};

function request(url, obj) {
  obj = obj || {};
  var key = url + JSON.stringify(obj);
  if (__reqCache[key]) return __reqCache[key];

  // 同步桥：flutter_js 的 sendMessage 在部分平台是异步的，
  // 这里先发请求，规则侧若拿不到完整 body 可改用 fetch。
  var payload = JSON.stringify({
    url: String(url),
    method: (obj.method || 'GET'),
    headers: obj.headers || {},
    body: obj.body || obj.data || null,
    timeout: obj.timeout || 15000
  });

  var raw = sendMessage('native_request', payload);
  // sendMessage 可能返回 Promise 字符串，简单处理
  try {
    if (typeof raw === 'string' && raw.indexOf('{') === 0) {
      var parsed = JSON.parse(raw);
      var body = parsed.body || '';
      __reqCache[key] = body;
      return body;
    }
  } catch (e) {}
  return raw ? String(raw) : '';
}

function post(url, obj) {
  obj = obj || {};
  obj.method = 'POST';
  return request(url, obj);
}

function fetch(url, obj) {
  return request(url, obj);
}

// ===== 极简 HTML 解析（够用演示，生产请换完整解析器）=====
function pdfh(html, rule) {
  if (!html || !rule) return '';
  // 支持简单的 "标签&&属性" 或纯文本截取
  try {
    // 取文本
    if (rule.indexOf('&&') > -1) {
      var parts = rule.split('&&');
      var tag = parts[0].trim();
      var attr = (parts[1] || 'Text').trim();
      var re;
      if (attr === 'Text' || attr === 'text') {
        re = new RegExp('<' + tag + '[^>]*>([\\s\\S]*?)</' + tag + '>', 'i');
        var m = html.match(re);
        return m ? m[1].replace(/<[^>]+>/g, '').trim() : '';
      } else {
        re = new RegExp('<' + tag + '[^>]*' + attr + '=["\']?([^"\'\\s>]+)', 'i');
        var m2 = html.match(re);
        return m2 ? m2[1] : '';
      }
    }
    // 纯正则
    var m3 = html.match(new RegExp(rule, 'i'));
    return m3 ? (m3[1] || m3[0]) : '';
  } catch (e) {
    return '';
  }
}

function pdfa(html, rule) {
  if (!html || !rule) return [];
  var list = [];
  try {
    var tag = rule.split('&&')[0].trim();
    var re = new RegExp('<' + tag + '[^>]*>[\\s\\S]*?</' + tag + '>', 'gi');
    var m;
    while ((m = re.exec(html)) !== null) {
      list.push(m[0]);
    }
  } catch (e) {}
  return list;
}

function pd(html, rule, baseUrl) {
  var v = pdfh(html, rule);
  if (baseUrl) v = joinUrl(baseUrl, v);
  return v;
}

// ===== 结果回传 =====
function setResult(arr) {
  sendMessage('native_setResult', JSON.stringify(arr || []));
  return arr;
}

function setHome(obj) {
  sendMessage('native_setResult', JSON.stringify(obj || {}));
  return obj;
}

function setHomeVod(obj) {
  return setHome(obj);
}

// 常用空实现，避免规则报错
function getCrypto() { return {}; }
function getCryptoJS() { return {}; }
function gzip() { return ''; }
function uget() { return ''; }
function log(msg) { print(msg); }

// 导出到全局
var g = (typeof globalThis !== 'undefined') ? globalThis : this;
g.request = request;
g.post = post;
g.fetch = fetch;
g.pdfh = pdfh;
g.pdfa = pdfa;
g.pd = pd;
g.joinUrl = joinUrl;
g.urljoin = urljoin;
g.setResult = setResult;
g.setHome = setHome;
g.setHomeVod = setHomeVod;
g.print = print;
g.log = log;
''';
}
