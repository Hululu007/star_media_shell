import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../models/source.dart';
import '../../../models/vod.dart';
import '../base_spider.dart';
import 'drpy_host.dart';

/// Drpy2 规则爬虫
///
/// 使用方式：
/// 1. Source.api 指向规则 JS 的 URL 或本地内容
/// 2. 规则需实现常见入口：home / homeVod / category / detail / search / play
///
/// 当前为可用骨架：能加载规则、执行函数、解析 JSON 结果。
/// 复杂规则（大量同步 request）建议后续升级为 WebView Host。
class DrpySpider extends BaseSpider {
  DrpySpider(this._source);

  final Source _source;
  DrpyHost? _host;
  String? _ruleSource;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
  ));

  @override
  Source get source => _source;

  @override
  Future<void> init() async {
    _host = DrpyHost();
    _ruleSource = await _loadRuleSource();
    if (_ruleSource != null && _ruleSource!.isNotEmpty) {
      await _host!.loadRule(_ruleSource!);
    }
  }

  Future<String> _loadRuleSource() async {
    final api = _source.api.trim();
    if (api.isEmpty) return '';

    // 本地演示规则
    if (api.startsWith('mock://') || api == 'drpy://demo') {
      return _demoRule;
    }

    // 直接是 JS 代码
    if (api.contains('var rule') || api.contains('function')) {
      return api;
    }

    // URL
    if (api.startsWith('http://') || api.startsWith('https://')) {
      final resp = await _dio.get<String>(api);
      return resp.data ?? '';
    }

    return api;
  }

  @override
  Future<HomeResult> home({String? filter}) async {
    await _ensureInit();

    // 优先调 home / homeVod
    dynamic raw = await _callRule('home', []);
    if (raw == null || (raw is List && raw.isEmpty)) {
      raw = await _callRule('homeVod', []);
    }

    // 也尝试从 lastResult 取
    raw ??= _host?.lastResult;

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
        for (final v in vodList) {
          if (v is Map) {
            list.add(Vod.fromJson(Map<String, dynamic>.from(v))
                .copyWith(sourceKey: source.key));
          }
        }
      }
    } else if (raw is List) {
      for (final v in raw) {
        if (v is Map) {
          list.add(Vod.fromJson(Map<String, dynamic>.from(v))
              .copyWith(sourceKey: source.key));
        }
      }
    }

    // 如果规则没返回分类，给默认
    if (classes.isEmpty && list.isNotEmpty) {
      classes.addAll(const [
        VodCategory(typeId: '1', typeName: '电影'),
        VodCategory(typeId: '2', typeName: '剧集'),
      ]);
    }

    return HomeResult(classes: classes, list: list);
  }

  @override
  Future<List<Vod>> category({
    required String typeId,
    int page = 1,
    String? filter,
  }) async {
    await _ensureInit();
    final raw = await _callRule('category', [typeId, page, filter ?? '', '']);
    return _parseVodList(raw);
  }

  @override
  Future<Vod> detail(String id) async {
    await _ensureInit();
    final raw = await _callRule('detail', [id]);

    if (raw is Map) {
      final vod = Vod.fromJson(Map<String, dynamic>.from(raw))
          .copyWith(sourceKey: source.key);

      // 解析分集：vod_play_from + vod_play_url 或 list
      final episodes = <Episode>[];
      final playFrom = raw['vod_play_from']?.toString() ?? raw['playFrom']?.toString();
      final playUrl = raw['vod_play_url']?.toString() ?? raw['playUrl']?.toString();

      if (playFrom != null && playUrl != null) {
        final flags = playFrom.split('\$\$\$');
        final urls = playUrl.split('\$\$\$');
        for (var i = 0; i < flags.length && i < urls.length; i++) {
          final flag = flags[i];
          final parts = urls[i].split('#');
          for (final p in parts) {
            if (p.isEmpty) continue;
            final segs = p.split('\$');
            if (segs.length >= 2) {
              episodes.add(Episode(name: segs[0], url: segs[1], flag: flag));
            } else if (segs.length == 1) {
              episodes.add(Episode(name: segs[0], url: segs[0], flag: flag));
            }
          }
        }
      }

      return vod.copyWith(episodes: episodes);
    }

    // 兜底
    return Vod(id: id, name: id, sourceKey: source.key);
  }

  @override
  Future<List<Vod>> search(String keyword, {int page = 1}) async {
    await _ensureInit();
    final raw = await _callRule('search', [keyword, page == 1, 'quick']);
    return _parseVodList(raw);
  }

  @override
  Future<PlayResult> play({
    required String id,
    required String flag,
    required String play,
  }) async {
    await _ensureInit();
    final raw = await _callRule('play', [flag, play, id]);

    if (raw is Map) {
      final url = raw['url']?.toString() ?? raw['parse']?.toString() ?? play;
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
              lang: s['lang']?.toString() ?? s['language']?.toString(),
            ));
          }
        }
      }
      return PlayResult(
        url: url,
        headers: headers,
        parse: raw['parse'] is int ? raw['parse'] as int : 0,
        jx: raw['jx'] is int ? raw['jx'] as int : 0,
        danmaku: raw['danmaku']?.toString() ?? raw['danmu']?.toString(),
        subtitles: subs,
      );
    }

    if (raw is String && raw.startsWith('http')) {
      return PlayResult(url: raw);
    }

    // 直链
    return PlayResult(url: play);
  }

  @override
  Future<void> dispose() async {
    _host?.dispose();
    _host = null;
  }

  Future<void> _ensureInit() async {
    if (_host == null) await init();
  }

  /// 调用规则函数，兼容多种写法
  Future<dynamic> _callRule(String name, List<dynamic> args) async {
    if (_host == null) return null;

    final argsJson = jsonEncode(args);
    // 多种可能的入口
    final candidates = [
      // 标准 function name(...)
      '''
      (function(){
        try {
          if (typeof $name === 'function') {
            var r = $name.apply(null, $argsJson);
            if (r && typeof r.then === 'function') return r;
            setResult(r);
            return JSON.stringify(r);
          }
          if (typeof rule !== 'undefined' && typeof rule.$name === 'function') {
            var r2 = rule.$name.apply(rule, $argsJson);
            setResult(r2);
            return JSON.stringify(r2);
          }
          return null;
        } catch(e) {
          return JSON.stringify({__error: String(e)});
        }
      })()
      ''',
    ];

    for (final code in candidates) {
      try {
        final resultStr = await _host!.evaluateAsync(code);
        if (resultStr.isEmpty || resultStr == 'null') {
          if (_host!.lastResult != null) return _host!.lastResult;
          continue;
        }
        final decoded = jsonDecode(resultStr);
        if (decoded is Map && decoded.containsKey('__error')) {
          debugPrint('Drpy rule error ($name): ${decoded['__error']}');
          continue;
        }
        return decoded ?? _host!.lastResult;
      } catch (e) {
        debugPrint('Drpy call $name failed: $e');
      }
    }

    return _host!.lastResult;
  }

  List<Vod> _parseVodList(dynamic raw) {
    final list = <Vod>[];
    if (raw is List) {
      for (final v in raw) {
        if (v is Map) {
          list.add(Vod.fromJson(Map<String, dynamic>.from(v))
              .copyWith(sourceKey: source.key));
        }
      }
    } else if (raw is Map) {
      final arr = raw['list'] ?? raw['data'] ?? [];
      if (arr is List) {
        for (final v in arr) {
          if (v is Map) {
            list.add(Vod.fromJson(Map<String, dynamic>.from(v))
                .copyWith(sourceKey: source.key));
          }
        }
      }
    }
    return list;
  }

  /// 供 WebSpider 等复用
  static const String demoRulePublic = _demoRule;

  /// 内置演示规则（纯 JS，不依赖外部网络）
  static const String _demoRule = r'''
var rule = {
  title: '演示Drpy源',
  host: 'https://example.com',
};

function home() {
  return {
    class: [
      { type_id: '1', type_name: '电影' },
      { type_id: '2', type_name: '剧集' },
      { type_id: '3', type_name: '综艺' },
      { type_id: '4', type_name: '动漫' }
    ],
    list: homeVod()
  };
}

function homeVod() {
  var arr = [];
  var names = ['星际穿越','盗梦空间','寄生虫','千与千寻','你的名字','复仇者联盟','肖申克的救赎','阿甘正传','泰坦尼克号','盗梦空间2','流浪地球','哪吒之魔童降世'];
  for (var i = 0; i < names.length; i++) {
    arr.push({
      vod_id: 'drpy_' + i,
      vod_name: names[i],
      vod_pic: 'https://picsum.photos/seed/drpy' + i + '/300/450',
      vod_remarks: i % 2 === 0 ? '高清' : '更新至' + (i+8) + '集',
      vod_year: '202' + (i % 5),
      type_name: i % 2 === 0 ? '电影' : '剧集'
    });
  }
  return arr;
}

function category(tid, pg, filter, extend) {
  pg = pg || 1;
  if (pg > 3) return [];
  return homeVod().map(function(v, idx) {
    v.vod_id = 'drpy_cat_' + tid + '_' + pg + '_' + idx;
    v.vod_name = v.vod_name + ' P' + pg;
    v.type_name = tid === '1' ? '电影' : (tid === '2' ? '剧集' : '其他');
    return v;
  });
}

function detail(id) {
  return {
    vod_id: id,
    vod_name: 'Drpy演示影片',
    vod_pic: 'https://picsum.photos/seed/detail/300/450',
    vod_year: '2024',
    vod_area: '中国大陆',
    type_name: '剧情',
    vod_actor: '演示演员A / 演示演员B',
    vod_director: '演示导演',
    vod_content: '这是 Drpy2 规则引擎返回的详情内容。用于验证 JS 运行时与宿主环境是否正常工作。',
    vod_play_from: '线路1$$$线路2',
    vod_play_url: '第01集$https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4#第02集$https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4$$$第01集$https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4'
  };
}

function search(wd, quick, pg) {
  pg = pg || 1;
  if (pg > 3) return [];
  return homeVod().map(function(v, idx) {
    v.vod_id = 'drpy_s_' + pg + '_' + idx;
    v.vod_name = wd + ' · ' + v.vod_name + ' P' + pg;
    return v;
  });
}

function play(flag, id, flags) {
  // id 在这里其实是 play url
  return {
    parse: 0,
    url: id,
    header: {},
    danmaku: 'asset://assets/media/demo_danmaku.json',
    subtitles: [
      { name: '中文外挂', url: 'asset://assets/media/demo.srt', lang: 'zh' }
    ]
  };
}
''';
}
