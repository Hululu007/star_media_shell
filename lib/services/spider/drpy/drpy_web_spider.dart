import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../models/source.dart';
import '../../../models/vod.dart';
import '../base_spider.dart';
import 'drpy_spider.dart';
import 'drpy_web_host.dart';

/// 使用 WebView 宿主的 Drpy 爬虫
///
/// 若 WebView 尚未就绪，自动回退到 [DrpySpider]（QuickJS）。
class DrpyWebSpider extends BaseSpider {
  DrpyWebSpider(this._source);

  final Source _source;
  DrpySpider? _fallback;
  bool _useWeb = false;
  String? _ruleSource;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
  ));

  @override
  Source get source => _source;

  @override
  Future<void> init() async {
    _ruleSource = await _loadRuleSource();

    // 等待 WebView 宿主（最多 2 秒）
    try {
      await DrpyWebHost.instance.ready.timeout(const Duration(seconds: 2));
      if (_ruleSource != null && _ruleSource!.isNotEmpty) {
        await DrpyWebHost.instance.loadRule(_ruleSource!);
        _useWeb = true;
        debugPrint('[DrpyWebSpider] using WebView host');
        return;
      }
    } catch (e) {
      debugPrint('[DrpyWebSpider] WebView not ready, fallback to QuickJS: $e');
    }

    _fallback = DrpySpider(_source);
    await _fallback!.init();
  }

  Future<String> _loadRuleSource() async {
    final api = _source.api.trim();
    if (api.isEmpty) return '';
    if (api.startsWith('mock://') || api == 'drpy://demo') {
      return DrpySpider.demoRulePublic;
    }
    if (api.contains('var rule') || api.contains('function home')) {
      return api;
    }
    if (api.startsWith('http://') || api.startsWith('https://')) {
      final resp = await _dio.get<String>(api);
      return resp.data ?? '';
    }
    return api;
  }

  @override
  Future<HomeResult> home({String? filter}) async {
    if (!_useWeb) return _fallback!.home(filter: filter);

    dynamic raw = await DrpyWebHost.instance.call('home', []);
    if (raw == null || (raw is List && raw.isEmpty)) {
      raw = await DrpyWebHost.instance.call('homeVod', []);
    }
    return _parseHome(raw);
  }

  @override
  Future<List<Vod>> category({
    required String typeId,
    int page = 1,
    String? filter,
  }) async {
    if (!_useWeb) {
      return _fallback!.category(typeId: typeId, page: page, filter: filter);
    }
    final raw = await DrpyWebHost.instance.call('category', [typeId, page, filter ?? '', '']);
    return _parseList(raw);
  }

  @override
  Future<Vod> detail(String id) async {
    if (!_useWeb) return _fallback!.detail(id);

    final raw = await DrpyWebHost.instance.call('detail', [id]);
    if (raw is Map) {
      final vod = Vod.fromJson(Map<String, dynamic>.from(raw))
          .copyWith(sourceKey: source.key);
      final episodes = _parseEpisodes(raw);
      return vod.copyWith(episodes: episodes);
    }
    return Vod(id: id, name: id, sourceKey: source.key);
  }

  @override
  Future<List<Vod>> search(String keyword, {int page = 1}) async {
    if (!_useWeb) return _fallback!.search(keyword, page: page);
    final raw = await DrpyWebHost.instance.call('search', [keyword, page == 1, 'quick']);
    return _parseList(raw);
  }

  @override
  Future<PlayResult> play({
    required String id,
    required String flag,
    required String play,
  }) async {
    if (!_useWeb) {
      return _fallback!.play(id: id, flag: flag, play: play);
    }
    final raw = await DrpyWebHost.instance.call('play', [flag, play, id]);
    if (raw is Map) {
      final url = raw['url']?.toString() ?? play;
      final headers = <String, String>{};
      if (raw['header'] is Map) {
        (raw['header'] as Map).forEach((k, v) {
          headers[k.toString()] = v.toString();
        });
      }
      final subs = <SubtitleRef>[];
      final subRaw = raw['subtitles'] ?? raw['subt'] ?? raw['subs'];
      if (subRaw is List) {
        for (final s in subRaw) {
          if (s is Map) {
            final u = s['url']?.toString() ?? '';
            if (u.isEmpty) continue;
            subs.add(SubtitleRef(
              name: s['name']?.toString() ?? s['label']?.toString() ?? '字幕',
              url: u,
              lang: s['lang']?.toString(),
            ));
          }
        }
      }
      return PlayResult(
        url: url,
        headers: headers,
        parse: raw['parse'] is int ? raw['parse'] as int : 0,
        danmaku: raw['danmaku']?.toString() ?? raw['danmu']?.toString(),
        subtitles: subs,
      );
    }
    if (raw is String && raw.startsWith('http')) {
      return PlayResult(url: raw);
    }
    return PlayResult(url: play);
  }

  @override
  Future<void> dispose() async {
    await _fallback?.dispose();
  }

  HomeResult _parseHome(dynamic raw) {
    final classes = <VodCategory>[];
    final list = <Vod>[];
    if (raw is Map) {
      final classList = raw['class'] ?? raw['classes'] ?? [];
      if (classList is List) {
        for (final c in classList) {
          if (c is Map) {
            classes.add(VodCategory.fromJson(Map<String, dynamic>.from(c)));
          }
        }
      }
      final vodList = raw['list'] ?? [];
      if (vodList is List) {
        list.addAll(_parseList(vodList));
      }
    } else if (raw is List) {
      list.addAll(_parseList(raw));
    }
    if (classes.isEmpty && list.isNotEmpty) {
      classes.addAll(const [
        VodCategory(typeId: '1', typeName: '电影'),
        VodCategory(typeId: '2', typeName: '剧集'),
      ]);
    }
    return HomeResult(classes: classes, list: list);
  }

  List<Vod> _parseList(dynamic raw) {
    final list = <Vod>[];
    final arr = raw is List ? raw : (raw is Map ? (raw['list'] ?? []) : []);
    if (arr is List) {
      for (final v in arr) {
        if (v is Map) {
          list.add(Vod.fromJson(Map<String, dynamic>.from(v))
              .copyWith(sourceKey: source.key));
        }
      }
    }
    return list;
  }

  List<Episode> _parseEpisodes(Map raw) {
    final episodes = <Episode>[];
    final playFrom = raw['vod_play_from']?.toString();
    final playUrl = raw['vod_play_url']?.toString();
    if (playFrom == null || playUrl == null) return episodes;
    final flags = playFrom.split('\$\$\$');
    final urls = playUrl.split('\$\$\$');
    for (var i = 0; i < flags.length && i < urls.length; i++) {
      final flag = flags[i];
      for (final p in urls[i].split('#')) {
        if (p.isEmpty) continue;
        final segs = p.split('\$');
        if (segs.length >= 2) {
          episodes.add(Episode(name: segs[0], url: segs[1], flag: flag));
        } else {
          episodes.add(Episode(name: segs[0], url: segs[0], flag: flag));
        }
      }
    }
    return episodes;
  }
}
