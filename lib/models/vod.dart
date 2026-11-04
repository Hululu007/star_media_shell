import 'package:equatable/equatable.dart';

/// 影片 / 媒体条目
class Vod extends Equatable {
  const Vod({
    required this.id,
    required this.name,
    this.pic,
    this.remarks,
    this.year,
    this.area,
    this.type,
    this.actor,
    this.director,
    this.des,
    this.sourceKey,
    this.episodes = const [],
  });

  final String id;
  final String name;
  final String? pic;
  final String? remarks; // 更新状态 / 清晰度
  final String? year;
  final String? area;
  final String? type;
  final String? actor;
  final String? director;
  final String? des;
  final String? sourceKey; // 来自哪个源
  final List<Episode> episodes;

  Vod copyWith({
    String? id,
    String? name,
    String? pic,
    String? remarks,
    String? year,
    String? area,
    String? type,
    String? actor,
    String? director,
    String? des,
    String? sourceKey,
    List<Episode>? episodes,
  }) {
    return Vod(
      id: id ?? this.id,
      name: name ?? this.name,
      pic: pic ?? this.pic,
      remarks: remarks ?? this.remarks,
      year: year ?? this.year,
      area: area ?? this.area,
      type: type ?? this.type,
      actor: actor ?? this.actor,
      director: director ?? this.director,
      des: des ?? this.des,
      sourceKey: sourceKey ?? this.sourceKey,
      episodes: episodes ?? this.episodes,
    );
  }

  factory Vod.fromJson(Map<String, dynamic> json) {
    return Vod(
      id: json['vod_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['vod_name']?.toString() ?? json['name']?.toString() ?? '',
      pic: json['vod_pic']?.toString() ?? json['pic']?.toString(),
      remarks: json['vod_remarks']?.toString() ?? json['remarks']?.toString(),
      year: json['vod_year']?.toString() ?? json['year']?.toString(),
      area: json['vod_area']?.toString() ?? json['area']?.toString(),
      type: json['type_name']?.toString() ?? json['type']?.toString(),
      actor: json['vod_actor']?.toString() ?? json['actor']?.toString(),
      director: json['vod_director']?.toString() ?? json['director']?.toString(),
      des: json['vod_content']?.toString() ?? json['des']?.toString(),
      sourceKey: json['sourceKey']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, name, sourceKey];
}

/// 分集
class Episode extends Equatable {
  const Episode({
    required this.name,
    required this.url,
    this.flag,
  });

  final String name;
  final String url;
  final String? flag; // 线路名

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      flag: json['flag']?.toString(),
    );
  }

  @override
  List<Object?> get props => [name, url, flag];
}

/// 分类
class VodCategory extends Equatable {
  const VodCategory({
    required this.typeId,
    required this.typeName,
    this.flag,
  });

  final String typeId;
  final String typeName;
  final String? flag;

  factory VodCategory.fromJson(Map<String, dynamic> json) {
    return VodCategory(
      typeId: json['type_id']?.toString() ?? json['id']?.toString() ?? '',
      typeName: json['type_name']?.toString() ?? json['name']?.toString() ?? '',
      flag: json['flag']?.toString(),
    );
  }

  @override
  List<Object?> get props => [typeId, typeName];
}
