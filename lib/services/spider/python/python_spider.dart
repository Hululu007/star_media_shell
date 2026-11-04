import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../models/source.dart';
import '../../../models/vod.dart';
import '../base_spider.dart';
import 'python_fallback.dart';
import 'python_host.dart';

/// Python 爬虫（TVBox / 催壳风格函数名）
class PythonSpider extends BaseSpider {
  PythonSpider(this._source);

  final Source _source;
  final _fallback = PythonFallbackEngine();
  String _module = 'spider';
  bool _native = false;

  @override
  Source get source => _source;

  @override
  Future<void> init() async {
    _module = 'spider_${_source.key}'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final script = await _loadScript();
    _native = await PythonHost.instance.isAvailable();
    if (_native && script.isNotEmpty) {
      try {
        await PythonHost.instance.loadScript(moduleName: _module, source: script);
        debugPrint('[PythonSpider] native runtime loaded');
        return;
      } catch (e) {
        debugPrint('[PythonSpider] native load failed: $e');
        _native = false;
      }
    }
    await _fallback.ensureDemoLoaded();
    debugPrint('[PythonSpider] using Dart fallback for ${_source.key}');
  }

  Future<String> _loadScript() async {
    final api = _source.api.trim();
    if (api.isEmpty || api == 'python://demo' || api.startsWith('mock://')) {
      return rootBundle.loadString('assets/python/demo_spider.py');
    }
    if (api.startsWith('asset://')) {
      return rootBundle.loadString(api.replaceFirst('asset://', ''));
    }
    if (api.startsWith('assets/')) {
      return rootBundle.loadString(api);
    }
    if (api.contains('def homeContent') || api.contains('def categoryContent')) {
      return api;
    }
    // URL: 由原生侧下载更合适；此处仅作占位
    if (api.startsWith('http')) {
      return rootBundle.loadString('assets/python/demo_spider.py');
    }
    return api;
  }

  Future<dynamic> _call(String method, List<dynamic> args) async {
    if (_native) {
      try {
        return await PythonHost.instance.call(_module, method, args);
      } catch (e) {
        debugPrint('[PythonSpider] native call $method failed: $e');
      }
    }
    return _fallback.call(method, args);
  }

  @override
  Future<HomeResult> home({String? filter}) async {
    final raw = await _call('homeContent', [filter ?? false]);
    return _parseHome(raw);
  }

  @override
  Future<List<Vod>> category({
    required String typeId,
    int page = 1,
    String? filter,
  }) async {
    final raw = await _call('categoryContent', [typeId, page, filter ?? false, {}]);
    return _parseList(raw);
  }

  @override
  Future<Vod> detail(String id) async {
    final raw = await _call('detailContent', [
      [id]
    ]);
    final list = _parseList(raw);
    if (list.isEmpty) {
      return Vod(id: id, name: id, sourceKey: source.key);
    }
    final vod = list.first;
    // 详情结构通常带 play 字段
    Map? map;
    if (raw is Map && raw['list'] is List && (raw['list'] as List).isNotEmpty) {
      map = Map<String, dynamic>.from((raw['list'] as List).first as Map);
    }
    final episodes = map != null ? _parseEpisodes(map) : vod.episodes;
    return vod.copyWith(episodes: episodes, sourceKey: source.key);
  }

  @override
  Future<List<Vod>> search(String keyword, {int page = 1}) async {
    final raw = await _call('searchContent', [keyword, true, page]);
    return _parseList(raw);
  }

  @override
  Future<PlayResult> play({
    required String id,
    required String flag,
    required String play,
  }) async {
    final raw = await _call('playerContent', [flag, play, []]);
    if (raw is Map) {
      final url = raw['url']?.toString() ?? play;
      final headers = <String, String>{};
      if (raw['header'] is Map) {
        (raw['header'] as Map).forEach((k, v) {
          headers['$k'] = '$v';
        });
      }
      final subs = <SubtitleRef>[];
      final subRaw = raw['subtitles'];
      if (subRaw is List) {
        for (final s in subRaw) {
          if (s is Map) {
            final u = s['url']?.toString() ?? '';
            if (u.isEmpty) continue;
            subs.add(SubtitleRef(
              name: s['name']?.toString() ?? '字幕',
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
        danmaku: raw['danmaku']?.toString(),
        subtitles: subs,
      );
    }
    return PlayResult(url: play);
  }

  HomeResult _parseHome(dynamic raw) {
    final classes = <Category>[];
    final list = <Vod>[];
    if (raw is Map) {
      final classList = raw['class'] ?? [];
      if (classList is List) {
        for (final c in classList) {
          if (c is Map) {
            classes.add(Category.fromJson(Map<String, dynamic>.from(c)));
          }
        }
      }
      list.addAll(_parseList(raw));
    }
    return HomeResult(classes: classes, list: list);
  }

  List<Vod> _parseList(dynamic raw) {
    final out = <Vod>[];
    final arr = raw is List
        ? raw
        : (raw is Map ? (raw['list'] ?? []) : []);
    if (arr is List) {
      for (final v in arr) {
        if (v is Map) {
          out.add(Vod.fromJson(Map<String, dynamic>.from(v))
              .copyWith(sourceKey: source.key));
        }
      }
    }
    return out;
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
