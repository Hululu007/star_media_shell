import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/live_channel.dart';

/// 直播频道收藏（按 id）
class LiveFavoriteService {
  static const _key = 'live_fav_ids_v1';

  Future<Set<String>> loadIds() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    return raw.toSet();
  }

  Future<void> saveIds(Set<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, ids.toList());
  }

  Future<bool> toggle(String id) async {
    final ids = await loadIds();
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    await saveIds(ids);
    return ids.contains(id);
  }

  Future<bool> isFav(String id) async {
    return (await loadIds()).contains(id);
  }
}

final liveFavoriteServiceProvider = Provider((ref) => LiveFavoriteService());

final liveFavoriteIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.watch(liveFavoriteServiceProvider).loadIds();
});
