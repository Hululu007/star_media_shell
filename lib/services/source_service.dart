import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/source.dart';

/// 源管理服务
class SourceService {
  static const _keySources = 'sources_v1';
  static const _keyActive = 'active_source_key';

  Future<List<Source>> loadSources() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySources);
    if (raw == null || raw.isEmpty) {
      // 默认演示源
      return [
        const Source(
          key: 'drpy_demo',
          name: 'Drpy演示源',
          api: 'drpy://demo',
          type: SourceType.drpy,
          order: 0,
        ),
        const Source(
          key: 'python_demo',
          name: 'Python演示源',
          api: 'python://demo',
          type: SourceType.python,
          order: 1,
        ),
        const Source(
          key: 'mock_local',
          name: '本地Mock源',
          api: 'mock://local',
          type: SourceType.json,
          order: 2,
        ),
      ];
    }
    final list = jsonDecode(raw) as List;
    return list.map((e) => Source.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> saveSources(List<Source> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sources.map((e) => e.toJson()).toList());
    await prefs.setString(_keySources, raw);
  }

  Future<String?> loadActiveKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActive);
  }

  Future<void> saveActiveKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActive, key);
  }

  Future<void> addSource(Source source) async {
    final list = await loadSources();
    if (list.any((e) => e.key == source.key)) {
      throw Exception('源标识已存在');
    }
    list.add(source);
    await saveSources(list);
  }

  Future<void> updateSource(Source source) async {
    final list = await loadSources();
    final idx = list.indexWhere((e) => e.key == source.key);
    if (idx < 0) throw Exception('源不存在');
    list[idx] = source;
    await saveSources(list);
  }

  Future<void> removeSource(String key) async {
    final list = await loadSources();
    list.removeWhere((e) => e.key == key);
    await saveSources(list);
  }
}

final sourceServiceProvider = Provider<SourceService>((ref) {
  return SourceService();
});

/// 源列表
final sourcesProvider = FutureProvider<List<Source>>((ref) async {
  final service = ref.watch(sourceServiceProvider);
  return service.loadSources();
});
