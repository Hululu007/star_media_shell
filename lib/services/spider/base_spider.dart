import '../../models/source.dart';
import '../../models/vod.dart';

/// 所有爬虫引擎必须实现的统一接口
abstract class BaseSpider {
  /// 源配置
  Source get source;

  /// 初始化（加载规则、注入环境等）
  Future<void> init();

  /// 首页推荐 / 分类列表
  Future<HomeResult> home({String? filter});

  /// 分类内容
  Future<List<Vod>> category({
    required String typeId,
    int page = 1,
    String? filter,
  });

  /// 详情（含分集）
  Future<Vod> detail(String id);

  /// 搜索
  Future<List<Vod>> search(String keyword, {int page = 1});

  /// 播放地址解析（可选，部分源需要二次解析）
  Future<PlayResult> play({
    required String id,
    required String flag,
    required String play,
  });

  /// 释放资源
  Future<void> dispose() async {}
}

/// 首页结果
class HomeResult {
  const HomeResult({
    this.classes = const [],
    this.list = const [],
    this.filters = const {},
  });

  final List<VodCategory> classes;
  final List<Vod> list;
  final Map<String, dynamic> filters;
}

/// 播放结果
class PlayResult {
  const PlayResult({
    required this.url,
    this.headers = const {},
    this.parse = 0,
    this.jx = 0,
    this.danmaku,
    this.subtitles = const [],
  });

  final String url;
  final Map<String, String> headers;
  final int parse; // 0=直链 1=需要解析
  final int jx;
  /// 弹幕源 URL（XML / JSON）
  final String? danmaku;
  /// 外挂字幕 [{name,url,lang}]
  final List<SubtitleRef> subtitles;
}

/// 外挂字幕引用（由源返回）
class SubtitleRef {
  const SubtitleRef({
    required this.name,
    required this.url,
    this.lang,
  });

  final String name;
  final String url;
  final String? lang;
}
