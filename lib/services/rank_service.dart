import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vod.dart';
import 'spider/spider_manager.dart';

/// 榜单 / 热门行（对标催壳）
/// 优先远程 JSON，失败则用当前源 home 列表。
class RankService {
  RankService(this.ref);
  final Ref ref;

  static const _prefUrl = 'rank_json_url';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    responseType: ResponseType.plain,
  ));

  Future<String?> getRemoteUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefUrl);
  }

  Future<void> setRemoteUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefUrl, url.trim());
  }

  Future<List<Vod>> hotList({int limit = 12}) async {
    final url = await getRemoteUrl();
    if (url != null && url.startsWith('http')) {
      try {
        final list = await _loadRemote(url);
        if (list.isNotEmpty) return list.take(limit).toList();
      } catch (_) {}
    }
    final source = ref.read(activeSourceProvider);
    final spider = await ref.read(spiderManagerProvider).getSpider(source);
    final home = await spider.home();
    return home.list.take(limit).toList();
  }

  Future<List<Vod>> _loadRemote(String url) async {
    final resp = await _dio.get<String>(url);
    final decoded = jsonDecode(resp.data ?? '[]');
    final arr = decoded is List
        ? decoded
        : (decoded is Map ? (decoded['list'] ?? []) : []);
    final out = <Vod>[];
    if (arr is List) {
      for (final e in arr) {
        if (e is Map) {
          out.add(Vod.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return out;
  }
}

final rankServiceProvider = Provider((ref) => RankService(ref));

final hotRankProvider = FutureProvider<List<Vod>>((ref) async {
  return ref.watch(rankServiceProvider).hotList();
});
