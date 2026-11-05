import 'package:equatable/equatable.dart';

/// 源类型
enum SourceType {
  json,     // 普通 JSON 接口
  drpy,     // Drpy2 JS 规则
  jsrule,   // JSRule
  python,   // Python spider
  cat,      // Cat
  html,     // HTML 源
  other,
}

/// 影视源配置
class Source extends Equatable {
  const Source({
    required this.key,
    required this.name,
    required this.api,
    this.type = SourceType.json,
    this.ext,
    this.jar,
    this.playerUrl,
    this.searchable = true,
    this.filterable = true,
    this.enabled = true,
    this.order = 0,
    this.siteCount = 0,
    this.lastUsedAt,
    this.lastLatencyMs,
  });

  final String key;          // 唯一标识
  final String name;         // 显示名称
  final String api;          // 接口地址 / 规则文件路径
  final SourceType type;
  final String? ext;         // 扩展参数
  final String? jar;         // jar 路径（兼容）
  final String? playerUrl;   // 解析地址
  final bool searchable;
  final bool filterable;
  final bool enabled;
  final int order;
  final int siteCount;
  final DateTime? lastUsedAt;
  final int? lastLatencyMs;

  Source copyWith({
    String? key,
    String? name,
    String? api,
    SourceType? type,
    String? ext,
    String? jar,
    String? playerUrl,
    bool? searchable,
    bool? filterable,
    bool? enabled,
    int? order,
    int? siteCount,
    DateTime? lastUsedAt,
    int? lastLatencyMs,
  }) {
    return Source(
      key: key ?? this.key,
      name: name ?? this.name,
      api: api ?? this.api,
      type: type ?? this.type,
      ext: ext ?? this.ext,
      jar: jar ?? this.jar,
      playerUrl: playerUrl ?? this.playerUrl,
      searchable: searchable ?? this.searchable,
      filterable: filterable ?? this.filterable,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      siteCount: siteCount ?? this.siteCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'api': api,
        'type': type.name,
        'ext': ext,
        'jar': jar,
        'playerUrl': playerUrl,
        'searchable': searchable,
        'filterable': filterable,
        'enabled': enabled,
        'order': order,
        'siteCount': siteCount,
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'lastLatencyMs': lastLatencyMs,
      };

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      api: json['api']?.toString() ?? json['url']?.toString() ?? '',
      type: SourceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SourceType.json,
      ),
      ext: json['ext']?.toString(),
      jar: json['jar']?.toString(),
      playerUrl: json['playerUrl']?.toString() ?? json['playUrl']?.toString(),
      searchable: json['searchable'] as bool? ?? true,
      filterable: json['filterable'] as bool? ?? true,
      enabled: json['enabled'] as bool? ?? true,
      order: json['order'] as int? ?? 0,
      siteCount: json['siteCount'] as int? ?? 0,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse('${json['lastUsedAt']}')
          : null,
      lastLatencyMs: json['lastLatencyMs'] as int?,
    );
  }

  @override
  List<Object?> get props => [key];
}
