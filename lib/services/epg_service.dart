import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/epg.dart';

/// EPG 节目单（对标催壳直播导视）
/// 支持：
/// 1) 远程 JSON：{ "channelId": [ {title,start,end} ] }
/// 2) 无配置时用演示数据
class EpgService {
  static const _prefUrl = 'epg_json_url';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    responseType: ResponseType.plain,
  ));

  Future<String?> getUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefUrl);
  }

  Future<void> setUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefUrl, url.trim());
  }

  Future<Map<String, List<EpgProgram>>> loadAll() async {
    final url = await getUrl();
    if (url != null && url.startsWith('http')) {
      try {
        final resp = await _dio.get<String>(url);
        final body = (resp.data ?? '').trim();
        if (body.contains('<tv') || body.contains('<programme')) {
          return parseXmltv(body);
        }
        return parseJson(body.isEmpty ? '{}' : body);
      } catch (_) {}
    }
    return demo();
  }

  Map<String, List<EpgProgram>> parseJson(String body) {
    final decoded = jsonDecode(body);
    final out = <String, List<EpgProgram>>{};
    if (decoded is! Map) return out;
    decoded.forEach((k, v) {
      if (v is List) {
        out['$k'] = v
            .whereType<Map>()
            .map((e) => EpgProgram.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
      }
    });
    return out;
  }


  /// 简易 XMLTV：<programme channel="id" start="..." stop="..."><title>...
  Map<String, List<EpgProgram>> parseXmltv(String xml) {
    final out = <String, List<EpgProgram>>{};
    final progRe = RegExp(
      r'<programme\s+([^>]+)>([\s\S]*?)</programme>',
      caseSensitive: false,
    );
    for (final m in progRe.allMatches(xml)) {
      final attrs = m.group(1) ?? '';
      final body = m.group(2) ?? '';
      final ch = RegExp(r'channel="([^"]+)"', caseSensitive: false)
              .firstMatch(attrs)
              ?.group(1) ??
          '';
      final startRaw = RegExp(r'start="([^"]+)"', caseSensitive: false)
              .firstMatch(attrs)
              ?.group(1) ??
          '';
      final stopRaw = RegExp(r'stop="([^"]+)"', caseSensitive: false)
              .firstMatch(attrs)
              ?.group(1) ??
          '';
      final title = RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false)
              .firstMatch(body)
              ?.group(1)
              ?.trim() ??
          '节目';
      final desc = RegExp(r'<desc[^>]*>([^<]*)</desc>', caseSensitive: false)
          .firstMatch(body)
          ?.group(1)
          ?.trim();
      if (ch.isEmpty) continue;
      final start = _parseXmltvTime(startRaw);
      final end = _parseXmltvTime(stopRaw);
      out.putIfAbsent(ch, () => []).add(EpgProgram(
            title: title,
            start: start,
            end: end.isAfter(start) ? end : start.add(const Duration(minutes: 30)),
            desc: desc,
          ));
    }
    for (final e in out.values) {
      e.sort((a, b) => a.start.compareTo(b.start));
    }
    return out;
  }

  DateTime _parseXmltvTime(String raw) {
    // 20261103190000 +0000 或 ISO
    final s = raw.trim();
    if (s.length >= 14 && RegExp(r'^\d{14}').hasMatch(s)) {
      final y = int.parse(s.substring(0, 4));
      final mo = int.parse(s.substring(4, 6));
      final d = int.parse(s.substring(6, 8));
      final h = int.parse(s.substring(8, 10));
      final mi = int.parse(s.substring(10, 12));
      final sec = int.parse(s.substring(12, 14));
      return DateTime(y, mo, d, h, mi, sec);
    }
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  Map<String, List<EpgProgram>> demo() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day, now.hour);
    List<EpgProgram> gen(String prefix) {
      return List.generate(6, (i) {
        final start = base.add(Duration(hours: i - 1));
        return EpgProgram(
          title: '$prefix · 时段 ${i + 1}',
          start: start,
          end: start.add(const Duration(hours: 1)),
          desc: '演示 EPG 节目',
        );
      });
    }

    return {
      'ch_0': gen('综合A'),
      'ch_1': gen('综合B'),
      'ch_2': gen('纪录'),
      'ch_3': gen('动画'),
      'demo1': gen('演示A'),
      'demo2': gen('演示B'),
      'demo3': gen('纪录'),
      'demo4': gen('动画'),
    };
  }

  EpgProgram? nowPlaying(List<EpgProgram> list, [DateTime? at]) {
    final t = at ?? DateTime.now();
    for (final p in list) {
      if (p.isOnAt(t)) return p;
    }
    return null;
  }
}

final epgServiceProvider = Provider((ref) => EpgService());

final epgAllProvider =
    FutureProvider<Map<String, List<EpgProgram>>>((ref) async {
  return ref.watch(epgServiceProvider).loadAll();
});
