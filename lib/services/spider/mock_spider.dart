import '../../models/source.dart';
import '../../models/vod.dart';
import 'base_spider.dart';

/// 本地 Mock 爬虫（用于开发调试，不依赖真实接口）
class MockSpider extends BaseSpider {
  MockSpider(this._source);

  final Source _source;

  @override
  Source get source => _source;

  @override
  Future<void> init() async {
    // 模拟初始化延迟
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<HomeResult> home({String? filter}) async {
    await Future.delayed(const Duration(milliseconds: 300));

    return HomeResult(
      classes: const [
        VodCategory(typeId: '1', typeName: '电影'),
        VodCategory(typeId: '2', typeName: '剧集'),
        VodCategory(typeId: '3', typeName: '综艺'),
        VodCategory(typeId: '4', typeName: '动漫'),
        VodCategory(typeId: '5', typeName: '纪录片'),
      ],
      list: _mockList(12),
      filters: const {
        '类型': ['全部', '动作', '喜剧', '爱情', '科幻'],
        '年份': ['全部', '2025', '2024', '2023'],
        '地区': ['全部', '大陆', '香港', '美国', '日本'],
      },
    );
  }

  @override
  Future<List<Vod>> category({
    required String typeId,
    int page = 1,
    String? filter,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (page > 3) return [];
    final list = _mockList(12, typeId: typeId, page: page);
    if (filter == null || filter.isEmpty) return list;
    // 演示：把筛选条件体现在标题上，便于验证已下发
    return list
        .map((v) => v.copyWith(name: '${v.name} · $filter', remarks: filter))
        .toList();
  }

  @override
  Future<Vod> detail(String id) async {
    await Future.delayed(const Duration(milliseconds: 350));

    final base = _mockList(1).first;
    return base.copyWith(
      id: id,
      des: '这是一部精彩的影视作品。故事讲述了主角在面对困境时如何成长与抉择的过程。画面精美，剧情紧凑，值得一看。',
      actor: '张三 / 李四 / 王五',
      director: '赵导',
      year: '2024',
      area: '中国大陆',
      type: '剧情 / 爱情',
      episodes: [
        const Episode(
          name: 'Big Buck Bunny',
          url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          flag: '演示线路',
        ),
        const Episode(
          name: 'Elephant Dream',
          url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
          flag: '演示线路',
        ),
        const Episode(
          name: 'Sintel',
          url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
          flag: '演示线路',
        ),
        const Episode(
          name: 'Tears of Steel',
          url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
          flag: '演示线路2',
        ),
      ],
    );
  }

  @override
  Future<List<Vod>> search(String keyword, {int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (page > 3) return [];
    final all = _mockList(8, typeId: 'search', page: page);
    return all
        .map((v) => v.copyWith(name: '$keyword · ${v.name}'))
        .toList();
  }

  @override
  Future<PlayResult> play({
    required String id,
    required String flag,
    required String play,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // 演示直链 + 外挂字幕/弹幕
    const demo =
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    return PlayResult(
      url: play.startsWith('http') ? play : demo,
      subtitles: const [
        SubtitleRef(
          name: '中文外挂',
          url: 'asset://assets/media/demo.srt',
          lang: 'zh',
        ),
      ],
      danmaku: 'asset://assets/media/demo_danmaku.json',
    );
  }

  List<Vod> _mockList(int count, {String? typeId, int page = 1}) {
    final names = [
      '星辰大海', '夜色如歌', '时光旅人', '迷雾之城', '金色岁月',
      '风起云涌', '月下独行', '花开半夏', '追光者', '深海之谜',
      '山河故人', '白日梦想', '长夜将尽', '春风十里', '秋水伊人',
      '夏日终曲', '冬日暖阳', '云端之上',
    ];
    final remarks = ['更新至12集', '全24集', '高清', '4K', '更新中', '完结', '蓝光', '最新'];
    final years = ['2024', '2023', '2025', '2022'];

    return List.generate(count, (i) {
      final idx = (page - 1) * count + i;
      return Vod(
        id: 'mock_${typeId ?? 'home'}_$idx',
        name: names[idx % names.length],
        pic: 'https://picsum.photos/seed/star$idx/300/450',
        remarks: remarks[idx % remarks.length],
        year: years[idx % years.length],
        type: typeId == '1'
            ? '电影'
            : typeId == '2'
                ? '剧集'
                : '其他',
        sourceKey: source.key,
      );
    });
  }
}
