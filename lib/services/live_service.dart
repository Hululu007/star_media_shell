import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/live_channel.dart';

/// m3u / m3u8 直播列表解析（对标催壳直播订阅）
class LiveService {
  static const _prefUrl = 'live_m3u_url';
  static const _prefLocal = 'live_m3u_local_body';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.plain,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  ));

  Future<String?> getSavedUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefUrl);
  }

  Future<void> saveUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefUrl, url.trim());
  }

  Future<void> saveLocalBody(String body) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefLocal, body);
  }

  Future<String?> loadLocalBody() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefLocal);
  }

  /// 解析 m3u 文本
  List<LiveChannel> parseM3u(String body) {
    final lines = body.replaceAll('\r\n', '\n').split('\n');
    final list = <LiveChannel>[];
    String? name;
    String group = '未分组';
    String? logo;
    var idx = 0;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        // #EXTINF:-1 tvg-logo="..." group-title="新闻",CCTV1
        name = line.split(',').length > 1 ? line.split(',').last.trim() : '频道';
        final g = RegExp(r'group-title="([^"]*)"', caseSensitive: false)
            .firstMatch(line);
        if (g != null) group = g.group(1)!.isEmpty ? '未分组' : g.group(1)!;
        final l =
            RegExp(r'tvg-logo="([^"]*)"', caseSensitive: false).firstMatch(line);
        logo = l?.group(1);
      } else if (!line.startsWith('#')) {
        final url = line;
        if (url.startsWith('http') || url.startsWith('rtmp')) {
          list.add(LiveChannel(
            id: 'ch_${idx++}',
            name: name ?? '频道$idx',
            group: group,
            url: url,
            logo: logo,
          ));
        }
        name = null;
        logo = null;
        group = '未分组';
      }
    }
    return list;
  }

  Future<List<LiveChannel>> loadFromUrl(String url) async {
    final resp = await _dio.get<String>(url);
    return parseM3u(resp.data ?? '');
  }

  /// 内置演示 m3u
  String demoM3u() => '''
#EXTM3U
#EXTINF:-1 group-title="综合",演示频道 A
https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4
#EXTINF:-1 group-title="综合",演示频道 B
https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4
#EXTINF:-1 group-title="纪录",纪录片频道
https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4
#EXTINF:-1 group-title="动画",动画频道
https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4
''';

  List<LiveChannel> demoChannels() => parseM3u(demoM3u());
}

final liveServiceProvider = Provider((ref) => LiveService());

final liveChannelsAsyncProvider =
    FutureProvider<List<LiveChannel>>((ref) async {
  final svc = ref.watch(liveServiceProvider);
  final local = await svc.loadLocalBody();
  if (local != null && local.trim().isNotEmpty) {
    final list = svc.parseM3u(local);
    if (list.isNotEmpty) return list;
  }
  final url = await svc.getSavedUrl();
  if (url != null && url.startsWith('http')) {
    try {
      final list = await svc.loadFromUrl(url);
      if (list.isNotEmpty) return list;
    } catch (_) {}
  }
  return svc.demoChannels();
});
