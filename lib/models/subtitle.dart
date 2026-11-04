import 'package:equatable/equatable.dart';

/// 一条字幕
class SubtitleCue extends Equatable {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;

  bool contains(Duration position) =>
      position >= start && position < end;

  @override
  List<Object?> get props => [start, end, text];
}

/// 字幕轨
class SubtitleTrack extends Equatable {
  const SubtitleTrack({
    required this.id,
    required this.label,
    this.language,
    this.url,
    this.cues = const [],
    this.isBuiltIn = false,
  });

  final String id;
  final String label;
  final String? language;
  final String? url;
  final List<SubtitleCue> cues;
  final bool isBuiltIn;

  SubtitleTrack copyWith({List<SubtitleCue>? cues}) {
    return SubtitleTrack(
      id: id,
      label: label,
      language: language,
      url: url,
      cues: cues ?? this.cues,
      isBuiltIn: isBuiltIn,
    );
  }

  @override
  List<Object?> get props => [id];
}
