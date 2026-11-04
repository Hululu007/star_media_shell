import 'package:flutter/material.dart';

import '../../models/subtitle.dart';
import '../../models/vod.dart';

/// 选集底部面板
Future<Episode?> showEpisodeSheet({
  required BuildContext context,
  required List<Episode> allEpisodes,
  required Episode current,
  required String? currentFlag,
  required ValueChanged<String?> onFlagChanged,
}) async {
  final flags = <String>{};
  for (final e in allEpisodes) {
    flags.add(e.flag ?? '默认');
  }
  final flagList = flags.toList();
  String? flag = currentFlag ?? (flagList.isNotEmpty ? flagList.first : null);

  return showModalBottomSheet<Episode>(
    context: context,
    backgroundColor: const Color(0xFF1A1D24),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          final eps = allEpisodes
              .where((e) => (e.flag ?? '默认') == (flag ?? '默认'))
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('选集',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  if (flagList.length > 1)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: flagList.map((f) {
                          final sel = f == (flag ?? '');
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: sel,
                              onSelected: (_) {
                                flag = f;
                                onFlagChanged(f);
                                setModal(() {});
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: eps.length,
                      itemBuilder: (_, i) {
                        final ep = eps[i];
                        final cur =
                            ep.name == current.name && ep.url == current.url;
                        return ActionChip(
                          backgroundColor: cur
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          label: Text(
                            ep.name,
                            style: TextStyle(
                              color: cur ? Colors.white : null,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, ep),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class PlayerMoreOptions {
  const PlayerMoreOptions({
    required this.danmakuOn,
    required this.subtitleOn,
    required this.subtitleId,
    required this.danmakuOpacity,
    required this.speed,
    required this.subtitleTracks,
    required this.speeds,
    this.autoNext = true,
  });

  final bool danmakuOn;
  final bool subtitleOn;
  final String subtitleId;
  final double danmakuOpacity;
  final double speed;
  final List<SubtitleTrack> subtitleTracks;
  final List<double> speeds;
  final bool autoNext;
}

class PlayerMoreResult {
  const PlayerMoreResult({
    this.danmakuOn,
    this.subtitleOn,
    this.subtitleId,
    this.danmakuOpacity,
    this.speed,
    this.autoNext,
  });

  final bool? danmakuOn;
  final bool? subtitleOn;
  final String? subtitleId;
  final double? danmakuOpacity;
  final double? speed;
  final bool? autoNext;
}

Future<PlayerMoreResult?> showPlayerMoreSheet({
  required BuildContext context,
  required PlayerMoreOptions options,
}) {
  var danmakuOn = options.danmakuOn;
  var subtitleOn = options.subtitleOn;
  var subtitleId = options.subtitleId;
  var opacity = options.danmakuOpacity;
  var speed = options.speed;
  var autoNext = options.autoNext;

  return showModalBottomSheet<PlayerMoreResult>(
    context: context,
    backgroundColor: const Color(0xFF1A1D24),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('播放选项',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  SwitchListTile(
                    title:
                        const Text('弹幕', style: TextStyle(color: Colors.white)),
                    value: danmakuOn,
                    onChanged: (v) {
                      Navigator.pop(
                          ctx, PlayerMoreResult(danmakuOn: v));
                    },
                  ),
                  SwitchListTile(
                    title:
                        const Text('字幕', style: TextStyle(color: Colors.white)),
                    value: subtitleOn && subtitleId != 'off',
                    onChanged: (v) {
                      Navigator.pop(
                        ctx,
                        PlayerMoreResult(
                          subtitleOn: v,
                          subtitleId: v ? 'demo_zh' : 'off',
                        ),
                      );
                    },
                  ),
                  SwitchListTile(
                    title: const Text('自动连播下一集',
                        style: TextStyle(color: Colors.white)),
                    value: autoNext,
                    onChanged: (v) {
                      Navigator.pop(ctx, PlayerMoreResult(autoNext: v));
                    },
                  ),
                  const Divider(color: Colors.white12),
                  const Text('字幕轨', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: options.subtitleTracks.map((t) {
                      return ChoiceChip(
                        label: Text(t.label),
                        selected: t.id == subtitleId,
                        onSelected: (_) {
                          Navigator.pop(
                            ctx,
                            PlayerMoreResult(
                              subtitleId: t.id,
                              subtitleOn: t.id != 'off',
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('弹幕透明度', style: TextStyle(color: Colors.white70)),
                  Slider(
                    value: opacity,
                    onChanged: (v) => setModal(() => opacity = v),
                    onChangeEnd: (v) {
                      // 不立即关闭，用户可继续调倍速
                    },
                  ),
                  const Text('倍速', style: TextStyle(color: Colors.white70)),
                  Wrap(
                    spacing: 8,
                    children: options.speeds.map((s) {
                      return ChoiceChip(
                        label: Text('${s}x'),
                        selected: s == speed,
                        onSelected: (_) {
                          Navigator.pop(
                            ctx,
                            PlayerMoreResult(
                              speed: s,
                              danmakuOpacity: opacity,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(
                          ctx,
                          PlayerMoreResult(danmakuOpacity: opacity),
                        );
                      },
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
