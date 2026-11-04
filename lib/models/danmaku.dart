import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// 弹幕模式
enum DanmakuMode {
  scroll, // 滚动
  top,    // 顶部固定
  bottom, // 底部固定
}

/// 一条弹幕
class DanmakuItem extends Equatable {
  const DanmakuItem({
    required this.time,
    required this.text,
    this.mode = DanmakuMode.scroll,
    this.color = const Color(0xFFFFFFFF),
    this.fontSize = 16,
  });

  /// 出现时间（相对视频）
  final Duration time;
  final String text;
  final DanmakuMode mode;
  final Color color;
  final double fontSize;

  @override
  List<Object?> get props => [time, text, mode];
}

/// 弹幕源配置
class DanmakuSource {
  const DanmakuSource({
    required this.id,
    required this.name,
    this.url,
  });

  final String id;
  final String name;
  final String? url;
}
