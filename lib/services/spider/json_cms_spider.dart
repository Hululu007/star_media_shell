import 'package:dio/dio.dart';

import '../../models/source.dart';
import '../../models/vod.dart';
import 'base_spider.dart';

/// 标准「苹果 CMS / 采集站」JSON 接口
///
/// 兼容常见：
/// - `api.php/provide/vod/?ac=list`
/// - `api.php/provide/vod/from/...`
/// - 返回 class + list / vod_play_from + vod_play_url
///
/// 配置方式：源类型选 JSON，api 填采集站根地址（可含 provide/vod）
class JsonCmsSpider implements BaseSpider {
  JsonCmsSpider(this.source);

  @override
  final Source source;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.json,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept': 'application/json,text/plain,*/*',
    },
  ));

  late final String _base;

  @override
  Future<void> init() async {
    var api = source.api.trim();
    if (api.isEmpty) {
      throw StateError('采集站 api 为空');
    }
    final lower = api.toLowerCase();
    // TVBox 配置包 / 静态 json 不要改写成 provide 接口
    final isConfigFile = lower.endsWith('.json') ||
        lower.contains('tvbox') ||
        lower.contains('/fish.json');
    if (!isConfigFile &&
        !api.contains('provide') &&
        !api.contains('api.php') &&
        !api.contains('/vod')) {
      if (!api.endsWith('/')) api = '$api/';
      api = '${api}api.php/provide/vod/';
    }
    _base = api;
  }

  String _url(Map<String, String> params) {
    final u = Uri.parse(_base);
    final q = Map<String, String>.from(u.queryParameters)..addAll(params);
    return u.replace(queryParameters: q).toString();
  }

  Future<Map<String, dynamic>> _get(Map<String, String> params) async {
    final resp = await _dio.get<dynamic>(_url(params));
    final data = resp.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      // 偶发 text/json
      return {};
    }
    return {};
  }

  Vod _item(Map<String, dynamic> m) {
    return Vod(
      id: '${m['vod_id'] ?? m['id'] ?? ''}',
      name: '${m['vod_name'] ?? m['name'] ?? ''}',
      pic: '${m['vod_pic'] ?? m['pic'] ?? ''}',
      remarks: '${m['vod_remarks'] ?? m['remarks'] ?? m['vod_score'] ?? ''}',
      type: '${m['type_name'] ?? m['vod_class'] ?? ''}',
      year: '${m['vod_year'] ?? ''}',
      area: '${m['vod_area'] ?? ''}',
      actor: '${m['vod_actor'] ?? ''}',
      director: '${m['vod_director'] ?? ''}',
      des: '${m['vod_content'] ?? m['vod_blurb'] ?? ''}',
      sourceKey: source.key,
    );
  }

  List<Episode> _parseEpisodes(Map<String, dynamic> m) {
    final from = '${m['vod_play_from'] ?? ''}';
    final url = '${m['vod_play_url'] ?? ''}';
    if (from.isEmpty || url.isEmpty) return const [];

    final flags = from.split('\$\$\$');
    final groups = url.split('\$\$\$');
    final eps = <Episode>[];
    for (var i = 0; i < flags.length; i++) {
      final flag = flags[i].trim();
      if (flag.isEmpty) continue;
      final group = i < groups.length ? groups[i] : '';
      for (final part in group.split('#')) {
        if (part.trim().isEmpty) continue;
        final idx = part.indexOf('\$');
        if (idx <= 0) {
          eps.add(Episode(name: '正片', url: part.trim(), flag: flag));
        } else {
          eps.add(Episode(
            name: part.substring(0, idx).trim(),
            url: part.substring(idx + 1).trim(),
            flag: flag,
          ));
        }
      }
    }
    return eps;
  }

  @override
  Future<HomeResult> home({String? filter}) async {
    try {
      // 先探测是否为 TVBox 配置包（含 sites）
      try {
        final probe = await _dio.get<dynamic>(source.api);
        final data = probe.data;
        if (data is Map && data['sites'] is List) {
          throw StateError('当前是 TVBox 配置包，请到「资源」页选择具体站点，而不是配置地址本身');
        }
        if (data is String && data.contains('"sites"')) {
          throw StateError('当前是 TVBox 配置包，请到「资源」页选择具体站点');
        }
      } catch (e) {
        if (e is StateError) rethrow;
        // 探测失败继续走 CMS 逻辑
      }

      // 分类
      final classData = await _get({'ac': 'list'});
      final classes = <VodCategory>[];
      final classList = classData['class'] ?? classData['classes'];
      if (classList is List) {
        for (final c in classList) {
          if (c is Map) {
            classes.add(VodCategory(
              typeId: '${c['type_id'] ?? c['type_ID'] ?? ''}',
              typeName: '${c['type_name'] ?? c['type_Name'] ?? ''}',
            ));
          }
        }
      }

      // 最新
      final listData = await _get({'ac': 'detail', 'pg': '1'});
      // 有的站用 videolist 无 ids 表示最新
      var raw = listData['list'];
      if (raw is! List || raw.isEmpty) {
        final alt = await _get({'ac': 'videolist', 'pg': '1'});
        raw = alt['list'];
      }
      final list = <Vod>[];
      if (raw is List) {
        for (final e in raw.take(24)) {
          if (e is Map) list.add(_item(Map<String, dynamic>.from(e)));
        }
      }

      if (classes.isEmpty && list.isEmpty) {
        throw StateError('接口无数据');
      }
      return HomeResult(classes: classes, list: list);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Vod>> category({
    required String typeId,
    int page = 1,
    String? filter,
  }) async {
    final data = await _get({
      'ac': 'detail',
      't': typeId,
      'pg': '$page',
      if (filter != null && filter.isNotEmpty) 'f': filter,
    });
    var raw = data['list'];
    if (raw is! List || raw.isEmpty) {
      final alt = await _get({
        'ac': 'videolist',
        't': typeId,
        'pg': '$page',
      });
      raw = alt['list'];
    }
    final list = <Vod>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) list.add(_item(Map<String, dynamic>.from(e)));
      }
    }
    return list;
  }

  @override
  Future<Vod> detail(String id) async {
    final data = await _get({'ac': 'detail', 'ids': id});
    final raw = data['list'];
    if (raw is! List || raw.isEmpty) {
      throw StateError('详情为空');
    }
    final m = Map<String, dynamic>.from(raw.first as Map);
    final vod = _item(m);
    return vod.copyWith(
      des: (vod.des != null && vod.des!.isNotEmpty) ? vod.des : '${m['vod_content'] ?? ''}',
      episodes: _parseEpisodes(m),
    );
  }

  @override
  Future<List<Vod>> search(String keyword, {int page = 1}) async {
    final data = await _get({
      'ac': 'detail',
      'wd': keyword,
      'pg': '$page',
    });
    final raw = data['list'];
    final list = <Vod>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) list.add(_item(Map<String, dynamic>.from(e)));
      }
    }
    return list;
  }

  @override
  Future<PlayResult> play({
    required String id,
    required String flag,
    required String play,
  }) async {
    // 采集站直链一般已在分集 url；parse=1 时交给解析（占位直通）
    final needParse = source.playerUrl != null && source.playerUrl!.isNotEmpty;
    if (needParse) {
      // 简易：playerUrl + url=
      final jx = source.playerUrl!;
      final sep = jx.contains('?') ? '&' : '?';
      final target = '$jx${sep}url=${Uri.encodeComponent(play)}';
      return PlayResult(url: target, parse: 1, jx: 1);
    }
    return PlayResult(url: play, parse: 0);
  }

  @override
  Future<void> dispose() async {
    _dio.close(force: true);
  }
}
