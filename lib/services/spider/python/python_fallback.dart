import 'dart:convert';

import 'package:flutter/services.dart';

/// 无原生 Python 时，用内置演示逻辑模拟 demo_spider.py 行为
/// （保证开发期可跑通；真机接 Chaquopy 后走 PythonHost）
class PythonFallbackEngine {
  Map<String, dynamic>? _cachedDemo;

  Future<void> ensureDemoLoaded() async {
    if (_cachedDemo != null) return;
    try {
      await rootBundle.loadString('assets/python/demo_spider.py');
    } catch (_) {}
    _cachedDemo = {'ok': true};
  }

  dynamic call(String method, List<dynamic> args) {
    switch (method) {
      case 'homeContent':
        return {
          'class': [
            {'type_id': '1', 'type_name': '电影'},
            {'type_id': '2', 'type_name': '剧集'},
            {'type_id': '3', 'type_name': '综艺'},
            {'type_id': '4', 'type_name': '动漫'},
          ],
          'list': _homeList(),
        };
      case 'homeVideoContent':
        return _homeList();
      case 'categoryContent':
        final tid = args.isNotEmpty ? '${args[0]}' : '1';
        final pg = args.length > 1 ? int.tryParse('${args[1]}') ?? 1 : 1;
        if (pg > 3) return {'list': []};
        final items = _homeList();
        for (var i = 0; i < items.length; i++) {
          items[i]['vod_id'] = 'py_cat_${tid}_${pg}_$i';
          items[i]['vod_name'] = '${items[i]['vod_name']} · P$pg';
          items[i]['type_name'] = tid == '1' ? '电影' : '剧集';
        }
        return {'list': items};
      case 'detailContent':
        final id = args.isNotEmpty
            ? (args[0] is List ? '${(args[0] as List).first}' : '${args[0]}')
            : 'py_0';
        return {
          'list': [
            {
              'vod_id': id,
              'vod_name': 'Python演示影片',
              'vod_pic': 'https://picsum.photos/seed/pydetail/300/450',
              'vod_year': '2024',
              'vod_area': '中国大陆',
              'type_name': '剧情',
              'vod_actor': '演员A / 演员B',
              'vod_director': '导演C',
              'vod_content': 'Python 回退引擎返回的详情（原生运行时未就绪时）。',
              'vod_play_from': '线路1\$\$\$线路2',
              'vod_play_url':
                  '第01集\$https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
                  '#第02集\$https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4'
                  '\$\$\$第01集\$https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
            }
          ]
        };
      case 'searchContent':
        final key = args.isNotEmpty ? '${args[0]}' : '';
        final pg = args.length > 2 ? int.tryParse('${args[2]}') ?? 1 : 1;
        if (pg > 2) return {'list': []};
        final items = _homeList().take(6).map((e) {
          final m = Map<String, dynamic>.from(e);
          m['vod_name'] = '$key · ${m['vod_name']}';
          return m;
        }).toList();
        return {'list': items};
      case 'playerContent':
        final id = args.length > 1 ? '${args[1]}' : '';
        return {
          'parse': 0,
          'url': id,
          'header': {},
          'danmaku': 'asset://assets/media/demo_danmaku.json',
          'subtitles': [
            {
              'name': '中文外挂',
              'url': 'asset://assets/media/demo.srt',
              'lang': 'zh',
            }
          ],
        };
      default:
        return null;
    }
  }

  List<Map<String, dynamic>> _homeList() {
    const names = [
      '星际穿越',
      '盗梦空间',
      '寄生虫',
      '千与千寻',
      '你的名字',
      '流浪地球',
      '哪吒之魔童降世',
      '肖申克的救赎',
    ];
    return List.generate(names.length, (i) {
      return {
        'vod_id': 'py_$i',
        'vod_name': names[i],
        'vod_pic': 'https://picsum.photos/seed/py$i/300/450',
        'vod_remarks': i % 2 == 0 ? '高清' : '更新至${i + 8}集',
        'vod_year': '202${i % 5}',
        'type_name': i % 2 == 0 ? '电影' : '剧集',
      };
    });
  }

  /// 调试：把结果打成 JSON
  String encode(dynamic v) => jsonEncode(v);
}
