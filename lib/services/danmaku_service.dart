import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/danmaku.dart';

/// 弹幕加载：支持 JSON 数组、简易 XML（B站风格 d 节点）
class DanmakuService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.plain,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  ));

  Future<List<DanmakuItem>> loadFromUrl(String url) async {
    String body;
    if (url.startsWith('asset://')) {
      body = await rootBundle.loadString(url.replaceFirst('asset://', ''));
    } else if (url.startsWith('assets/')) {
      body = await rootBundle.loadString(url);
    } else {
      final resp = await _dio.get<String>(url);
      body = resp.data ?? '';
    }
    body = body.trim();
    if (body.isEmpty) return [];
    if (body.startsWith('[') || body.startsWith('{')) {
      return parseJson(body);
    }
    if (body.contains('<') && (body.contains('<d ') || body.contains('<i>'))) {
      return parseBilibiliXml(body);
    }
    // 纯文本：每行  time|text  或  time,text
    return parsePlain(body);
  }

  List<DanmakuItem> parseJson(String body) {
    final list = <DanmakuItem>[];
    final decoded = jsonDecode(body);
    final arr = decoded is List
        ? decoded
        : (decoded is Map ? (decoded['data'] ?? decoded['danmaku'] ?? []) : []);
    if (arr is! List) return list;
    for (final e in arr) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final text = (m['text'] ?? m['content'] ?? m['msg'] ?? '').toString();
      if (text.isEmpty) continue;
      final timeSec = _asDouble(m['time'] ?? m['t'] ?? m['stime'] ?? 0);
      final mode = _modeFrom(m['mode'] ?? m['type'] ?? 1);
      final color = _colorFrom(m['color'] ?? m['c'] ?? 0xFFFFFF);
      final size = _asDouble(m['size'] ?? m['fontSize'] ?? 16);
      list.add(DanmakuItem(
        time: Duration(milliseconds: (timeSec * 1000).round()),
        text: text,
        mode: mode,
        color: color,
        fontSize: size.clamp(12, 28),
      ));
    }
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  /// B站弹幕 XML：<d p="time,mode,size,color,...">text</d>
  List<DanmakuItem> parseBilibiliXml(String xml) {
    final list = <DanmakuItem>[];
    final re = RegExp(r'<d\s+p="([^"]*)"[^>]*>([^<]*)</d>', caseSensitive: false);
    for (final m in re.allMatches(xml)) {
      final p = m.group(1) ?? '';
      final text = _unescape(m.group(2) ?? '').trim();
      if (text.isEmpty) continue;
      final parts = p.split(',');
      final timeSec = parts.isNotEmpty ? double.tryParse(parts[0]) ?? 0 : 0;
      final modeInt = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
      final size = parts.length > 2 ? double.tryParse(parts[2]) ?? 16 : 16;
      final colorInt = parts.length > 3 ? int.tryParse(parts[3]) ?? 0xFFFFFF : 0xFFFFFF;
      list.add(DanmakuItem(
        time: Duration(milliseconds: (timeSec * 1000).round()),
        text: text,
        mode: _modeFrom(modeInt),
        color: _colorFrom(colorInt),
        fontSize: (size / 2).clamp(12, 28), // B站字号偏大，缩半
      ));
    }
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  List<DanmakuItem> parsePlain(String body) {
    final list = <DanmakuItem>[];
    for (final line in body.split('\n')) {
      final s = line.trim();
      if (s.isEmpty || s.startsWith('#')) continue;
      final sep = s.contains('|') ? '|' : ',';
      final i = s.indexOf(sep);
      if (i <= 0) continue;
      final t = double.tryParse(s.substring(0, i).trim()) ?? 0;
      final text = s.substring(i + 1).trim();
      if (text.isEmpty) continue;
      list.add(DanmakuItem(
        time: Duration(milliseconds: (t * 1000).round()),
        text: text,
      ));
    }
    return list;
  }

  List<DanmakuItem> demoDanmaku() {
    final list = <DanmakuItem>[];
    final samples = [
      '来了来了',
      '高清真舒服',
      '星辰影音 yyds',
      '弹幕演示',
      '前排围观',
      '支持外挂弹幕源',
      '字幕弹幕都有了',
      '继续加油',
      '这条是彩色弹幕',
      '底部弹幕测试',
      '顶部弹幕测试',
      '233333',
      '好活',
      '妙啊',
    ];
    final colors = [
      Colors.white,
      const Color(0xFF74B9FF),
      const Color(0xFF55EFC4),
      const Color(0xFFFF7675),
      const Color(0xFFFDCB6E),
      const Color(0xFFFD79A8),
      const Color(0xFFA29BFE),
    ];
    for (var i = 0; i < 60; i++) {
      final t = Duration(milliseconds: 800 + i * 1200);
      final mode = i % 11 == 0
          ? DanmakuMode.top
          : (i % 13 == 0 ? DanmakuMode.bottom : DanmakuMode.scroll);
      list.add(DanmakuItem(
        time: t,
        text: samples[i % samples.length],
        mode: mode,
        color: colors[i % colors.length],
        fontSize: 15 + (i % 3).toDouble(),
      ));
    }
    return list;
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  DanmakuMode _modeFrom(dynamic v) {
    final n = v is int ? v : int.tryParse(v?.toString() ?? '') ?? 1;
    // B站: 4底 5顶 其它滚动
    if (n == 4) return DanmakuMode.bottom;
    if (n == 5) return DanmakuMode.top;
    if (v == 'top') return DanmakuMode.top;
    if (v == 'bottom') return DanmakuMode.bottom;
    return DanmakuMode.scroll;
  }

  Color _colorFrom(dynamic v) {
    int n;
    if (v is int) {
      n = v;
    } else if (v is String) {
      final s = v.replaceFirst('#', '');
      n = int.tryParse(s, radix: s.length > 2 ? 16 : 10) ?? 0xFFFFFF;
    } else {
      n = 0xFFFFFF;
    }
    if (n <= 0xFFFFFF) n = 0xFF000000 | n;
    return Color(n);
  }

  String _unescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#10;', ' ');
}

final danmakuServiceProvider = Provider<DanmakuService>((ref) {
  return DanmakuService();
});
