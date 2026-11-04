import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.once = true,
  });

  final String id;
  final String title;
  final String body;
  final bool once;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: '${j['id'] ?? j['title'] ?? ''}',
        title: '${j['title'] ?? '公告'}',
        body: '${j['body'] ?? j['content'] ?? ''}',
        once: j['once'] != false,
      );
}

class AnnouncementService {
  static const _prefPrefix = 'announce_seen_';
  static const _prefRemote = 'announce_remote_url';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
    responseType: ResponseType.plain,
  ));

  List<Announcement> builtins() => const [
        Announcement(
          id: 'welcome_v1',
          title: '欢迎使用星辰影音',
          body: '对标催壳的多运行时影视壳。\n'
              '支持 Drpy / Python 源、外挂字幕弹幕、直播 m3u、继续观看与快捷切源。\n'
              '长按首页源图标可快速切换源。',
          once: true,
        ),
      ];

  Future<String?> getRemoteUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefRemote);
  }

  Future<void> setRemoteUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefRemote, url.trim());
  }

  Future<List<Announcement>> fetchRemote(String url) async {
    final resp = await _dio.get<String>(url);
    final body = resp.data ?? '';
    final decoded = jsonDecode(body);
    final list = <Announcement>[];
    final arr = decoded is List ? decoded : (decoded is Map ? [decoded] : []);
    for (final e in arr) {
      if (e is Map) list.add(Announcement.fromJson(Map<String, dynamic>.from(e)));
    }
    return list;
  }

  Future<bool> hasSeen(String id) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('$_prefPrefix$id') ?? false;
  }

  Future<void> markSeen(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('$_prefPrefix$id', true);
  }

  Future<Announcement?> nextToShow() async {
    final candidates = <Announcement>[...builtins()];
    final url = await getRemoteUrl();
    if (url != null && url.startsWith('http')) {
      try {
        candidates.insertAll(0, await fetchRemote(url));
      } catch (_) {}
    }
    for (final a in candidates) {
      if (a.id.isEmpty) continue;
      if (!a.once) return a;
      if (!await hasSeen(a.id)) return a;
    }
    return null;
  }
}

final announcementServiceProvider = Provider((ref) => AnnouncementService());

Future<void> showAnnouncementIfNeeded(BuildContext context, WidgetRef ref) async {
  final svc = ref.read(announcementServiceProvider);
  final a = await svc.nextToShow();
  if (a == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text(a.title),
      content: SingleChildScrollView(child: Text(a.body)),
      actions: [
        TextButton(
          onPressed: () async {
            await svc.markSeen(a.id);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
