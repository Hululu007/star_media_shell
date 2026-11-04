import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vod.dart';

/// 本地存储：收藏 + 历史 + 搜索历史
class StorageService {
  static const _keyFavorites = 'favorites_v1';
  static const _keyHistory = 'history_v1';
  static const _keySearchHistory = 'search_history_v1';

  // ---------- 收藏 ----------
  Future<List<Vod>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFavorites);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Vod.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveFavorites(List<Vod> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFavorites,
      jsonEncode(list.map((e) => _vodToJson(e)).toList()),
    );
  }

  Future<bool> isFavorite(String id, {String? sourceKey}) async {
    final list = await loadFavorites();
    return list.any((v) => v.id == id && (sourceKey == null || v.sourceKey == sourceKey));
  }

  Future<void> toggleFavorite(Vod vod) async {
    final list = await loadFavorites();
    final idx = list.indexWhere(
      (v) => v.id == vod.id && v.sourceKey == vod.sourceKey,
    );
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.insert(0, vod);
    }
    await saveFavorites(list);
  }

  Future<void> removeFavorite(String id, {String? sourceKey}) async {
    final list = await loadFavorites();
    list.removeWhere(
      (v) => v.id == id && (sourceKey == null || v.sourceKey == sourceKey),
    );
    await saveFavorites(list);
  }

  // ---------- 观看历史 ----------
  Future<List<HistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyHistory);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveHistory(List<HistoryItem> list) async {
    final prefs = await SharedPreferences.getInstance();
    // 最多保留 100 条
    final trimmed = list.take(100).toList();
    await prefs.setString(
      _keyHistory,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addHistory({
    required Vod vod,
    required Episode episode,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
  }) async {
    final list = await loadHistory();
    list.removeWhere(
      (h) => h.vod.id == vod.id && h.vod.sourceKey == vod.sourceKey,
    );
    list.insert(
      0,
      HistoryItem(
        vod: vod,
        episodeName: episode.name,
        episodeUrl: episode.url,
        flag: episode.flag,
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await saveHistory(list);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }

  Future<void> removeHistory(String id, {String? sourceKey}) async {
    final list = await loadHistory();
    list.removeWhere(
      (h) => h.vod.id == id && (sourceKey == null || h.vod.sourceKey == sourceKey),
    );
    await saveHistory(list);
  }

  /// 查找某影片的历史记录
  Future<HistoryItem?> getHistoryItem(String id, {String? sourceKey}) async {
    final list = await loadHistory();
    try {
      return list.firstWhere(
        (h) => h.vod.id == id && (sourceKey == null || h.vod.sourceKey == sourceKey),
      );
    } catch (_) {
      return null;
    }
  }

  /// 仅更新进度（播放中定期调用）
  Future<void> updateProgress({
    required String id,
    String? sourceKey,
    required Duration position,
    required Duration duration,
    String? episodeName,
    String? episodeUrl,
    String? flag,
  }) async {
    final list = await loadHistory();
    final idx = list.indexWhere(
      (h) => h.vod.id == id && (sourceKey == null || h.vod.sourceKey == sourceKey),
    );
    if (idx < 0) return;
    final old = list[idx];
    list[idx] = HistoryItem(
      vod: old.vod,
      episodeName: episodeName ?? old.episodeName,
      episodeUrl: episodeUrl ?? old.episodeUrl,
      flag: flag ?? old.flag,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    // 移到最前
    final item = list.removeAt(idx);
    list.insert(0, item);
    await saveHistory(list);
  }

  // ---------- 搜索历史 ----------
  Future<List<String>> loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keySearchHistory) ?? [];
  }

  Future<void> addSearchKeyword(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keySearchHistory) ?? [];
    list.remove(k);
    list.insert(0, k);
    await prefs.setStringList(_keySearchHistory, list.take(20).toList());
  }

  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySearchHistory);
  }

  Map<String, dynamic> _vodToJson(Vod v) => {
        'vod_id': v.id,
        'vod_name': v.name,
        'vod_pic': v.pic,
        'vod_remarks': v.remarks,
        'vod_year': v.year,
        'vod_area': v.area,
        'type_name': v.type,
        'vod_actor': v.actor,
        'vod_director': v.director,
        'vod_content': v.des,
        'sourceKey': v.sourceKey,
      };
}

class HistoryItem {
  HistoryItem({
    required this.vod,
    required this.episodeName,
    required this.episodeUrl,
    this.flag,
    this.positionMs = 0,
    this.durationMs = 0,
    required this.updatedAt,
  });

  final Vod vod;
  final String episodeName;
  final String episodeUrl;
  final String? flag;
  final int positionMs;
  final int durationMs;
  final int updatedAt;

  double get progress {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'vod': {
          'vod_id': vod.id,
          'vod_name': vod.name,
          'vod_pic': vod.pic,
          'vod_remarks': vod.remarks,
          'vod_year': vod.year,
          'type_name': vod.type,
          'sourceKey': vod.sourceKey,
        },
        'episodeName': episodeName,
        'episodeUrl': episodeUrl,
        'flag': flag,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final vodMap = Map<String, dynamic>.from(json['vod'] as Map? ?? {});
    return HistoryItem(
      vod: Vod.fromJson(vodMap),
      episodeName: json['episodeName']?.toString() ?? '',
      episodeUrl: json['episodeUrl']?.toString() ?? '',
      flag: json['flag']?.toString(),
      positionMs: json['positionMs'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
      updatedAt: json['updatedAt'] as int? ?? 0,
    );
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final favoritesProvider = FutureProvider<List<Vod>>((ref) async {
  return ref.watch(storageServiceProvider).loadFavorites();
});

final historyProvider = FutureProvider<List<HistoryItem>>((ref) async {
  return ref.watch(storageServiceProvider).loadHistory();
});

final searchHistoryProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(storageServiceProvider).loadSearchHistory();
});
