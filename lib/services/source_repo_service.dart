import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/source.dart';
import 'source_service.dart';

/// 源仓库订阅项
class SourceRepo {
  const SourceRepo({
    required this.id,
    required this.name,
    required this.url,
    this.lastSync,
    this.lastCount = 0,
  });

  final String id;
  final String name;
  final String url;
  final DateTime? lastSync;
  final int lastCount;

  SourceRepo copyWith({
    String? name,
    String? url,
    DateTime? lastSync,
    int? lastCount,
  }) {
    return SourceRepo(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      lastSync: lastSync ?? this.lastSync,
      lastCount: lastCount ?? this.lastCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'lastSync': lastSync?.toIso8601String(),
        'lastCount': lastCount,
      };

  factory SourceRepo.fromJson(Map<String, dynamic> j) => SourceRepo(
        id: '${j['id'] ?? j['url'] ?? ''}',
        name: '${j['name'] ?? '仓库'}',
        url: '${j['url'] ?? ''}',
        lastSync: j['lastSync'] != null
            ? DateTime.tryParse('${j['lastSync']}')
            : null,
        lastCount: j['lastCount'] is int ? j['lastCount'] as int : 0,
      );
}

class RepoSyncResult {
  const RepoSyncResult({
    required this.added,
    required this.updated,
    required this.total,
    this.message,
  });

  final int added;
  final int updated;
  final int total;
  final String? message;
}

/// 源订阅仓库（对标催壳 / TVBox 订阅）
class SourceRepoService {
  static const _prefKey = 'source_repos_v1';

  final SourceService sourceService;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 25),
    responseType: ResponseType.plain,
    followRedirects: true,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  ));

  SourceRepoService(this.sourceService);

  Future<List<SourceRepo>> loadRepos() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => SourceRepo.fromJson(Map<String, dynamic>.from(e)))
          .where((r) => r.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRepos(List<SourceRepo> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addRepo(SourceRepo repo) async {
    final list = await loadRepos();
    if (list.any((e) => e.url == repo.url || e.id == repo.id)) {
      final i = list.indexWhere((e) => e.url == repo.url || e.id == repo.id);
      list[i] = repo.copyWith(name: repo.name, url: repo.url);
    } else {
      list.add(repo);
    }
    await saveRepos(list);
  }

  Future<void> removeRepo(String id) async {
    final list = await loadRepos();
    list.removeWhere((e) => e.id == id);
    await saveRepos(list);
  }

  /// 拉取仓库文本并解析为 Source 列表
  Future<List<Source>> fetchSources(String url) async {
    String body;
    if (url.startsWith('asset://')) {
      // 由调用方用 rootBundle；这里仅 HTTP
      throw StateError('asset url should be loaded by UI layer');
    }
    if (url == 'demo://repo' || url == 'python://demo') {
      return _demoSources();
    }
    final resp = await _dio.get<String>(url);
    body = (resp.data ?? '').toString();
    if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
      body = body.substring(1);
    }
    final parsed = parseRepoBody(body);
    if (parsed.isEmpty) {
      throw StateError('配置已下载但未解析出站点（${body.length} 字节）');
    }
    return parsed;
  }


  bool _asBool(dynamic v, {bool fallback = true}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  /// 兼容多种仓库格式
  List<Source> parseRepoBody(String body) {
    body = body.trim();
    if (body.isEmpty) return [];

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      // 按行： name,url,type
      return _parseLineFormat(body);
    }

    final out = <Source>[];

    if (decoded is List) {
      for (var i = 0; i < decoded.length; i++) {
        final e = decoded[i];
        if (e is Map) {
          try {
            final s = _mapToSource(Map<String, dynamic>.from(e), i);
            if (s != null) out.add(s);
          } catch (_) {}
        } else if (e is String && e.startsWith('http')) {
          out.add(Source(
            key: 'repo_$i',
            name: '订阅源$i',
            api: e,
            type: SourceType.json,
            order: i,
          ));
        }
      }
      return out;
    }

    if (decoded is Map) {
      final rootJar = (decoded['spider'] ?? decoded['jar'] ?? '').toString();
      // TVBox: sites / urls / sources
      final urls = decoded['sites'] ?? decoded['urls'] ?? decoded['sources'];
      if (urls is List) {
        for (var i = 0; i < urls.length; i++) {
          final e = urls[i];
          if (e is Map) {
            try {
              final s = _mapToSource(
                Map<String, dynamic>.from(e),
                i,
                rootJar: rootJar.isEmpty ? null : rootJar,
              );
              if (s != null) out.add(s);
            } catch (_) {
              // 单站异常不拖垮整包
            }
          } else if (e is String && e.startsWith('http')) {
            out.add(Source(
              key: 'repo_url_$i',
              name: '订阅$i',
              api: e,
              type: SourceType.json,
              order: i,
            ));
          }
        }
        // lives 可选：写入一条直播相关提示源（api 为 m3u 时）
        final lives = decoded['lives'];
        if (lives is List) {
          for (var i = 0; i < lives.length; i++) {
            final e = lives[i];
            if (e is! Map) continue;
            final m = Map<String, dynamic>.from(e);
            final u = (m['url'] ?? m['api'] ?? '').toString();
            final n = (m['name'] ?? '直播$i').toString();
            if (u.startsWith('http')) {
              out.add(Source(
                key: 'live_${n.hashCode.abs()}_$i',
                name: '📺 $n',
                api: u,
                type: SourceType.other,
                searchable: false,
                order: 10000 + i,
              ));
            }
          }
        }
        return out;
      }
      // 单源
      final s = _mapToSource(Map<String, dynamic>.from(decoded), 0,
          rootJar: rootJar.isEmpty ? null : rootJar);
      if (s != null) out.add(s);
    }
    return out;
  }

  Source? _mapToSource(Map<String, dynamic> j, int index, {String? rootJar}) {
    final api = (j['api'] ?? j['url'] ?? j['api_url'] ?? '').toString().trim();
    final name = (j['name'] ?? j['title'] ?? '源$index').toString().trim();
    if (api.isEmpty && name.isEmpty) return null;
    var key = (j['key'] ?? j['id'] ?? '').toString().trim();
    if (key.isEmpty) {
      key = 'repo_${name.hashCode.abs()}_$index';
    }

    // TVBox type: 0 xml 1 json 2? 3 csp/jar 4 drpy
    SourceType type = SourceType.json;
    final rawType = j['type'] ?? j['sourceType'];
    final t = rawType?.toString().toLowerCase() ?? '';
    final ti = _asInt(rawType, fallback: -1);
    if (ti == 1 || t == '1') {
      type = SourceType.json;
    } else if (ti == 3 || t == '3' || api.startsWith('csp_')) {
      type = SourceType.cat; // jar/csp 站
    } else if (ti == 4 || t.contains('drpy') || api.contains('drpy2') || api.endsWith('.js')) {
      type = SourceType.drpy;
    } else if (t.contains('python') || api.endsWith('.py') || api.startsWith('python://')) {
      type = SourceType.python;
    } else if (t.contains('js')) {
      type = SourceType.jsrule;
    } else if (api.startsWith('http') && (api.contains('provide') || api.contains('api.php'))) {
      type = SourceType.json;
    }

    // jar: site jar or root spider (strip ;md5;...)
    var jar = (j['jar'] ?? rootJar ?? '').toString().trim();
    if (jar.contains(';')) jar = jar.split(';').first.trim();

    // ext may be Map
    String? ext;
    final ev = j['ext'];
    if (ev is Map || ev is List) {
      try {
        ext = jsonEncode(ev);
      } catch (_) {
        ext = ev.toString();
      }
    } else if (ev != null) {
      ext = ev.toString();
    }

    return Source(
      key: key,
      name: name,
      api: api.isEmpty ? name : api,
      type: type,
      ext: ext,
      jar: jar.isEmpty ? null : jar,
      playerUrl: j['playerUrl']?.toString() ?? j['playUrl']?.toString(),
      searchable: _asBool(j['searchable'], fallback: true),
      filterable: _asBool(j['filterable'], fallback: true),
      enabled: _asBool(j['enabled'], fallback: true),
      order: _asInt(j['order'], fallback: index),
      siteCount: 1,
    );
  }

  List<Source> _parseLineFormat(String body) {
    final out = <Source>[];
    var i = 0;
    for (final line in body.split('\n')) {
      final s = line.trim();
      if (s.isEmpty || s.startsWith('#')) continue;
      final parts = s.split(',');
      if (parts.length >= 2) {
        out.add(Source(
          key: 'line_${i}_${parts[0].hashCode.abs()}',
          name: parts[0].trim(),
          api: parts[1].trim(),
          type: parts.length > 2
              ? SourceType.values.firstWhere(
                  (e) => e.name == parts[2].trim(),
                  orElse: () => SourceType.json,
                )
              : SourceType.json,
          order: i,
        ));
        i++;
      }
    }
    return out;
  }

  List<Source> _demoSources() => const [
        Source(
          key: 'repo_demo_drpy',
          name: '仓库·Drpy演示',
          api: 'drpy://demo',
          type: SourceType.drpy,
          order: 10,
        ),
        Source(
          key: 'repo_demo_py',
          name: '仓库·Python演示',
          api: 'python://demo',
          type: SourceType.python,
          order: 11,
        ),
        Source(
          key: 'repo_demo_mock',
          name: '仓库·Mock演示',
          api: 'mock://local',
          type: SourceType.json,
          order: 12,
        ),
      ];

  /// 同步仓库源：合并进本地（按 key 更新）
  Future<RepoSyncResult> syncRepo(SourceRepo repo, {List<Source>? prefetched}) async {
    final remote = prefetched ?? await fetchSources(repo.url);
    if (remote.isEmpty) {
      return const RepoSyncResult(
        added: 0,
        updated: 0,
        total: 0,
        message: '仓库为空或解析失败',
      );
    }
    final local = await sourceService.loadSources();
    final byKey = {for (final s in local) s.key: s};
    var added = 0;
    var updated = 0;
    for (final s in remote) {
      if (byKey.containsKey(s.key)) {
        byKey[s.key] = s.copyWith(order: byKey[s.key]!.order);
        updated++;
      } else {
        byKey[s.key] = s;
        added++;
      }
    }
    final merged = byKey.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    await sourceService.saveSources(merged);

    final repos = await loadRepos();
    final i = repos.indexWhere((e) => e.id == repo.id);
    if (i >= 0) {
      repos[i] = repo.copyWith(
        lastSync: DateTime.now(),
        lastCount: remote.length,
      );
      await saveRepos(repos);
    }

    return RepoSyncResult(
      added: added,
      updated: updated,
      total: remote.length,
    );
  }
}

final sourceRepoServiceProvider = Provider((ref) {
  return SourceRepoService(ref.watch(sourceServiceProvider));
});

final sourceReposProvider = FutureProvider<List<SourceRepo>>((ref) async {
  return ref.watch(sourceRepoServiceProvider).loadRepos();
});
