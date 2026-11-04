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
    body = resp.data ?? '';
    return parseRepoBody(body);
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
          final s = _mapToSource(Map<String, dynamic>.from(e), i);
          if (s != null) out.add(s);
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
      // TVBox: { "urls": [ {name,url} ] }
      final urls = decoded['urls'] ?? decoded['sites'] ?? decoded['sources'];
      if (urls is List) {
        for (var i = 0; i < urls.length; i++) {
          final e = urls[i];
          if (e is Map) {
            final s = _mapToSource(Map<String, dynamic>.from(e), i);
            if (s != null) out.add(s);
          }
        }
        return out;
      }
      // 单源
      final s = _mapToSource(Map<String, dynamic>.from(decoded), 0);
      if (s != null) out.add(s);
    }
    return out;
  }

  Source? _mapToSource(Map<String, dynamic> j, int index) {
    final api = (j['api'] ?? j['url'] ?? j['api_url'] ?? '').toString();
    final name = (j['name'] ?? j['title'] ?? '源$index').toString();
    if (api.isEmpty && name.isEmpty) return null;
    var key = (j['key'] ?? j['id'] ?? '').toString();
    if (key.isEmpty) {
      key = 'repo_${name.hashCode.abs()}_$index';
    }
    SourceType type = SourceType.json;
    final t = (j['type'] ?? j['sourceType'] ?? '').toString().toLowerCase();
    if (t.contains('drpy') || t == '3') {
      type = SourceType.drpy;
    } else if (t.contains('python') || t == 'py') {
      type = SourceType.python;
    } else if (t.contains('js')) {
      type = SourceType.jsrule;
    } else {
      try {
        type = SourceType.values.firstWhere((e) => e.name == t);
      } catch (_) {}
    }
    // api 形态推断
    if (api.contains('drpy') || api.contains('var rule')) {
      type = SourceType.drpy;
    }
    if (api.startsWith('python://') || api.endsWith('.py')) {
      type = SourceType.python;
    }
    return Source(
      key: key,
      name: name,
      api: api.isEmpty ? name : api,
      type: type,
      ext: j['ext']?.toString(),
      jar: j['jar']?.toString(),
      playerUrl: j['playerUrl']?.toString() ?? j['playUrl']?.toString(),
      searchable: j['searchable'] as bool? ?? true,
      filterable: j['filterable'] as bool? ?? true,
      enabled: j['enabled'] as bool? ?? true,
      order: j['order'] as int? ?? index,
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
