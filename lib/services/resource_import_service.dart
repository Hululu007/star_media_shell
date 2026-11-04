import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/source.dart';
import 'live_service.dart';
import 'source_repo_service.dart';
import 'source_service.dart';

class ImportResult {
  const ImportResult({
    required this.message,
    this.sourcesAdded = 0,
    this.reposAdded = 0,
    this.liveChannels = 0,
  });
  final String message;
  final int sourcesAdded;
  final int reposAdded;
  final int liveChannels;
}

/// 资源导入：TVBox 订阅、粘贴配置、本地文件
class ResourceImportService {
  ResourceImportService(this._sources, this._repos, this._live);

  final SourceService _sources;
  final SourceRepoService _repos;
  final LiveService _live;

  /// 粘贴 TVBox / 站点 JSON 文本
  Future<ImportResult> importConfigText(String text) async {
    text = text.trim();
    if (text.isEmpty) {
      return const ImportResult(message: '内容为空');
    }

    // 纯 URL → 当仓库订阅
    if (text.startsWith('http://') || text.startsWith('https://')) {
      final repo = SourceRepo(
        id: 'repo_${text.hashCode.abs()}',
        name: '订阅 ${Uri.tryParse(text)?.host ?? "源"}',
        url: text,
      );
      await _repos.addRepo(repo);
      final sync = await _repos.syncRepo(repo);
      return ImportResult(
        message: '已订阅并同步：新增 ${sync.added}，更新 ${sync.updated}',
        sourcesAdded: sync.added,
        reposAdded: 1,
      );
    }

    // m3u
    if (text.contains('#EXTM3U') || text.contains('#EXTINF')) {
      await _live.saveLocalBody(text);
      final n = _live.parseM3u(text).length;
      return ImportResult(message: '已导入直播列表：$n 个频道', liveChannels: n);
    }

    // JSON
    try {
      final decoded = jsonDecode(text);
      // TVBox 仓库
      if (decoded is Map && (decoded['urls'] != null || decoded['sites'] != null)) {
        final list = _repos.parseRepoBody(text);
        if (list.isEmpty) {
          return const ImportResult(message: '未能解析出站点');
        }
        final local = await _sources.loadSources();
        final byKey = {for (final s in local) s.key: s};
        var added = 0;
        for (final s in list) {
          if (!byKey.containsKey(s.key)) added++;
          byKey[s.key] = s;
        }
        await _sources.saveSources(byKey.values.toList()
          ..sort((a, b) => a.order.compareTo(b.order)));
        return ImportResult(
          message: '已导入 ${list.length} 个站点（新增 $added）',
          sourcesAdded: added,
        );
      }
      // 单站点或数组
      final list = _repos.parseRepoBody(text);
      if (list.isNotEmpty) {
        final local = await _sources.loadSources();
        final byKey = {for (final s in local) s.key: s};
        var added = 0;
        for (final s in list) {
          if (!byKey.containsKey(s.key)) added++;
          byKey[s.key] = s;
        }
        await _sources.saveSources(byKey.values.toList());
        return ImportResult(
          message: '已导入 ${list.length} 个源（新增 $added）',
          sourcesAdded: added,
        );
      }
    } catch (_) {}

    // 按行 name,url
    final lines = text.split('\n').where((e) => e.trim().isNotEmpty).toList();
    if (lines.length >= 1 && lines.first.contains(',')) {
      final list = _repos.parseRepoBody(text);
      if (list.isNotEmpty) {
        for (final s in list) {
          try {
            await _sources.addSource(s);
          } catch (_) {
            await _sources.updateSource(s);
          }
        }
        return ImportResult(message: '已按行导入 ${list.length} 个源', sourcesAdded: list.length);
      }
    }

    return const ImportResult(message: '无法识别的配置格式');
  }

  /// TVBox 订阅地址
  Future<ImportResult> subscribeTvBox(String name, String url) async {
    url = url.trim();
    if (url.isEmpty) return const ImportResult(message: '地址为空');
    final repo = SourceRepo(
      id: 'tvbox_${url.hashCode.abs()}',
      name: name.trim().isEmpty ? 'TVBox 订阅' : name.trim(),
      url: url,
    );
    await _repos.addRepo(repo);
    final sync = await _repos.syncRepo(repo);
    return ImportResult(
      message: '同步完成：新增 ${sync.added}，更新 ${sync.updated}，共 ${sync.total}',
      sourcesAdded: sync.added,
      reposAdded: 1,
    );
  }

  /// 本地文本（m3u / json / txt）
  Future<ImportResult> importLocalText(String filename, String body) async {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.m3u') ||
        lower.endsWith('.m3u8') ||
        body.contains('#EXTM3U') ||
        body.contains('#EXTINF')) {
      await _live.saveLocalBody(body);
      final n = _live.parseM3u(body).length;
      return ImportResult(message: '直播列表已导入：$n 个频道', liveChannels: n);
    }
    return importConfigText(body);
  }
}

final resourceImportServiceProvider = Provider((ref) {
  return ResourceImportService(
    ref.watch(sourceServiceProvider),
    ref.watch(sourceRepoServiceProvider),
    ref.watch(liveServiceProvider),
  );
});
