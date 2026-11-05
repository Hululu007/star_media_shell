import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/source.dart';
import '../../models/vod.dart';
import 'base_spider.dart';
import 'drpy/drpy_spider.dart';
import 'drpy/drpy_web_spider.dart';
import 'python/python_spider.dart';
import 'mock_spider.dart';
import 'json_cms_spider.dart';
import '../source_service.dart';

/// 爬虫管理器：负责创建、缓存、切换不同引擎
class SpiderManager {
  SpiderManager();

  final Map<String, BaseSpider> _cache = {};

  BaseSpider _create(Source source) {
    switch (source.type) {
      case SourceType.drpy:
      case SourceType.jsrule:
        return DrpyWebSpider(source);
      case SourceType.python:
        return PythonSpider(source);
      case SourceType.cat:
      case SourceType.html:
        return MockSpider(source);
      case SourceType.json:
        if (source.api.startsWith('http://') || source.api.startsWith('https://')) {
          return JsonCmsSpider(source);
        }
        if (source.api.contains('drpy') || source.api.contains('var rule')) {
          return DrpyWebSpider(source);
        }
        return MockSpider(source);
      case SourceType.other:
      default:
        if (source.api.startsWith('http://') || source.api.startsWith('https://')) {
          return JsonCmsSpider(source);
        }
        if (source.api.contains('drpy') || source.api.contains('var rule')) {
          return DrpyWebSpider(source);
        }
        return MockSpider(source);
    }
  }

  Future<BaseSpider> getSpider(Source source) async {
    if (_cache.containsKey(source.key)) {
      return _cache[source.key]!;
    }
    final spider = _create(source);
    await spider.init();
    _cache[source.key] = spider;
    return spider;
  }

  Future<void> remove(String key) async {
    final spider = _cache.remove(key);
    await spider?.dispose();
  }

  Future<void> clear() async {
    for (final spider in _cache.values) {
      await spider.dispose();
    }
    _cache.clear();
  }
}

final spiderManagerProvider = Provider<SpiderManager>((ref) {
  return SpiderManager();
});

/// 当前激活的源
final activeSourceProvider = StateProvider<Source>((ref) {
  // 默认使用 Drpy 演示源
  return const Source(
    key: 'drpy_demo',
    name: 'Drpy演示源',
    api: 'drpy://demo',
    type: SourceType.drpy,
  );
});

final homeDataProvider = FutureProvider<HomeResult>((ref) async {
  final manager = ref.watch(spiderManagerProvider);
  var source = ref.watch(activeSourceProvider);

  // 激活源不可用时，自动切到第一个可首页源
  if (!source.canLoadHome) {
    try {
      final list = await ref.read(sourcesProvider.future);
      final better = list.where((s) => s.canLoadHome && s.enabled).toList();
      if (better.isNotEmpty) {
        source = better.first;
        ref.read(activeSourceProvider.notifier).state = source;
      }
    } catch (_) {}
  }

  try {
    final spider = await manager.getSpider(source);
    final home = await spider.home();
    if (home.list.isEmpty && home.classes.isEmpty) {
      throw StateError('首页无内容');
    }
    return home;
  } catch (e) {
    // 回退演示源，避免白屏
    try {
      final mock = const Source(
        key: 'mock_local',
        name: '本地Mock源',
        api: 'mock://local',
        type: SourceType.json,
      );
      final spider = await manager.getSpider(mock);
      final home = await spider.home();
      return home;
    } catch (_) {
      rethrow;
    }
  }
});

final categoryProvider =
    FutureProvider.family<List<Vod>, ({String typeId, int page})>((ref, params) async {
  final source = ref.watch(activeSourceProvider);
  final manager = ref.watch(spiderManagerProvider);
  final spider = await manager.getSpider(source);
  return spider.category(typeId: params.typeId, page: params.page);
});

final detailProvider = FutureProvider.family<Vod, String>((ref, id) async {
  final source = ref.watch(activeSourceProvider);
  final manager = ref.watch(spiderManagerProvider);
  final spider = await manager.getSpider(source);
  return spider.detail(id);
});
