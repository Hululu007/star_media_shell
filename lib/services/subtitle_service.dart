import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subtitle.dart';

/// 字幕解析与加载（网络 URL / asset:// / 内置演示）
class SubtitleService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    responseType: ResponseType.plain,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  ));

  Future<List<SubtitleCue>> loadFromUrl(String url) async {
    String body;
    if (url.startsWith('asset://')) {
      final path = url.replaceFirst('asset://', '');
      body = await rootBundle.loadString(path);
    } else if (url.startsWith('assets/')) {
      body = await rootBundle.loadString(url);
    } else {
      final resp = await _dio.get<String>(url);
      body = resp.data ?? '';
    }
    final lower = url.toLowerCase();
    if (lower.contains('.vtt') || body.trimLeft().startsWith('WEBVTT')) {
      return parseVtt(body);
    }
    return parseSrt(body);
  }

  Future<AppSubtitleTrack> loadTrack({
    required String id,
    required String label,
    required String url,
    String? language,
  }) async {
    final cues = await loadFromUrl(url);
    return AppSubtitleTrack(
      id: id,
      label: label,
      language: language,
      url: url,
      cues: cues,
    );
  }

  List<SubtitleCue> parseSrt(String content) {
    final cues = <SubtitleCue>[];
    final blocks = content.replaceAll('\r\n', '\n').split(RegExp(r'\n\n+'));
    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;
      var timeIdx = 0;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          timeIdx = i;
          break;
        }
      }
      final times = lines[timeIdx].split('-->');
      if (times.length < 2) continue;
      final start = _parseTs(times[0].trim());
      final end = _parseTs(times[1].trim().split(' ').first);
      final text = lines.sublist(timeIdx + 1).join('\n').trim();
      if (text.isEmpty) continue;
      cues.add(SubtitleCue(start: start, end: end, text: text));
    }
    return cues;
  }

  List<SubtitleCue> parseVtt(String content) {
    var body = content.replaceAll('\r\n', '\n');
    if (body.startsWith('WEBVTT')) {
      final idx = body.indexOf('\n');
      body = idx > 0 ? body.substring(idx) : body;
    }
    return parseSrt(body);
  }

  Duration _parseTs(String raw) {
    final s = raw.replaceAll(',', '.');
    final parts = s.split(':');
    try {
      if (parts.length == 3) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final secParts = parts[2].split('.');
        final sec = int.parse(secParts[0]);
        final ms = secParts.length > 1
            ? int.parse(secParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(hours: h, minutes: m, seconds: sec, milliseconds: ms);
      }
      if (parts.length == 2) {
        final m = int.parse(parts[0]);
        final secParts = parts[1].split('.');
        final sec = int.parse(secParts[0]);
        final ms = secParts.length > 1
            ? int.parse(secParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(minutes: m, seconds: sec, milliseconds: ms);
      }
    } catch (_) {}
    return Duration.zero;
  }

  List<AppSubtitleTrack> demoTracks() {
    return [
      const AppSubtitleTrack(id: 'off', label: '关闭', isBuiltIn: true),
      AppSubtitleTrack(
        id: 'demo_zh',
        label: '中文（内置）',
        language: 'zh',
        isBuiltIn: true,
        cues: [
          const SubtitleCue(
            start: Duration(seconds: 1),
            end: Duration(seconds: 4),
            text: '欢迎使用星辰影音',
          ),
          const SubtitleCue(
            start: Duration(seconds: 5),
            end: Duration(seconds: 9),
            text: '这是内置字幕演示',
          ),
        ],
      ),
    ];
  }
}

final subtitleServiceProvider = Provider<SubtitleService>((ref) {
  return SubtitleService();
});
