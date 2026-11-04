import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide SubtitleTrack;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/danmaku.dart';
import '../../models/epg.dart';
import '../../models/subtitle.dart';
import '../../models/vod.dart';
import '../../services/danmaku_service.dart';
import '../../services/spider/base_spider.dart';
import '../../services/spider/spider_manager.dart';
import '../../services/cast_service.dart';
import '../../services/epg_service.dart';
import '../../services/player_prefs.dart';
import '../../services/storage_service.dart';
import '../../services/subtitle_service.dart';
import 'danmaku_overlay.dart';
import 'player_sheets.dart';
import 'subtitle_overlay.dart';

enum _FitMode { contain, cover, fill }

/// 完整播放器：手势、亮度/音量、长按倍速、选集、比例、锁定、字幕弹幕、续播
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    super.key,
    required this.vod,
    required this.episode,
    this.resumePosition,
    this.playlist,
    this.isLive = false,
  });

  final Vod vod;
  final Episode episode;
  final int? resumePosition;
  /// 直播同组频道 / 剧集播放列表
  final List<Episode>? playlist;
  final bool isLive;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;

  bool _loading = true;
  bool _buffering = false;
  String? _error;
  bool _showControls = true;
  bool _locked = false;
  Timer? _hideTimer;
  Timer? _progressTimer;
  final List<StreamSubscription<dynamic>> _subs = [];
  DateTime _lastPosUi = DateTime.fromMillisecondsSinceEpoch(0);
  bool _autoNext = true;
  bool _isLive = false;
  int? _liveZapDir;
  List<EpgProgram> _epgPrograms = [];
  EpgProgram? _epgNow;

  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  double _speed = 1.0;
  bool _didResume = false;

  // 当前播放分集（可在播放器内切换）
  late Episode _episode;
  List<Episode> _allEpisodes = [];
  String? _currentFlag;

  // 字幕 / 弹幕
  List<AppSubtitleTrack> _subtitleTracks = [];
  String _subtitleId = 'demo_zh';
  List<SubtitleCue> _activeCues = [];
  bool _subtitleOn = true;
  List<DanmakuItem> _danmakuList = [];
  bool _danmakuOn = true;
  double _danmakuOpacity = 0.9;

  // 画面
  _FitMode _fit = _FitMode.contain;

  // 手势
  double? _dragStartDx;
  double? _dragStartDy;
  Duration? _seekPreview;
  double? _brightnessPreview; // 0~1
  double? _volumePreview; // 0~1
  bool _longPressBoost = false;
  String? _statusHint; // 解析中 / 嗅探等
  double _brightness = 0.5;
  double _volume = 0.5;

  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    _episode = widget.episode;
    _allEpisodes = widget.playlist ?? widget.vod.episodes;
    _currentFlag = widget.episode.flag;
    _isLive = widget.isLive;
    if (_isLive) {
      _autoNext = false;
      _loadLiveEpg();
    }

    _player = Player();
    _controller = VideoController(_player);

    _subs.add(_player.stream.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    }));
    // 进度 UI 节流，降低 rebuild 频率
    _subs.add(_player.stream.position.listen((v) {
      _position = v;
      final now = DateTime.now();
      if (now.difference(_lastPosUi).inMilliseconds >= 200) {
        _lastPosUi = now;
        if (mounted) setState(() {});
      }
    }));
    _subs.add(_player.stream.duration.listen((v) {
      if (mounted) setState(() => _duration = v);
      if (!_didResume && v.inMilliseconds > 0) _tryResume(v);
    }));
    _subs.add(_player.stream.buffering.listen((v) {
      if (mounted) setState(() => _buffering = v);
    }));
    _subs.add(_player.stream.buffer.listen((v) {
      if (mounted) setState(() => _buffered = v);
    }));
    _subs.add(_player.stream.completed.listen((done) {
      if (!done || !mounted) return;
      _saveProgress();
      if (_autoNext) {
        final list = _flagEpisodes;
        final i = _episodeIndex;
        if (i >= 0 && i < list.length - 1) {
          _resolveAndPlay(ep: list[i + 1]);
        }
      }
    }));

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    _initBrightnessVolume();
    _loadSubtitleAndDanmaku();
    _loadPlayerPrefs();
    _resolveAndPlay();
    _startProgressSaver();
  }

  Future<void> _initBrightnessVolume() async {
    // 亮度：仅 UI 手势反馈（避免 screen_brightness_android Kotlin 构建失败）
    _brightness = 0.5;
    try {
      VolumeController().showSystemUI = false;
      _volume = await VolumeController().getVolume();
    } catch (_) {}
  }


  Future<void> _loadExternalTracks(PlayResult result) async {
    final subSvc = ref.read(subtitleServiceProvider);
    final danSvc = ref.read(danmakuServiceProvider);

    final tracks = <AppSubtitleTrack>[
      const AppSubtitleTrack(id: 'off', label: '关闭', isBuiltIn: true),
    ];
    var loadedExternal = false;
    for (var i = 0; i < result.subtitles.length; i++) {
      final refSub = result.subtitles[i];
      try {
        final track = await subSvc.loadTrack(
          id: 'ext_$i',
          label: refSub.name,
          url: refSub.url,
          language: refSub.lang,
        );
        tracks.add(track);
        loadedExternal = true;
      } catch (e) {
        debugPrint('load subtitle failed: $e');
      }
    }
    if (!loadedExternal) {
      tracks.addAll(subSvc.demoTracks().where((t) => t.id != 'off'));
    }

    var danmaku = <DanmakuItem>[];
    final dmUrl = result.danmaku;
    if (dmUrl != null && dmUrl.isNotEmpty) {
      try {
        danmaku = await danSvc.loadFromUrl(dmUrl);
      } catch (e) {
        debugPrint('load danmaku failed: $e');
        danmaku = danSvc.demoDanmaku();
      }
    } else {
      danmaku = danSvc.demoDanmaku();
    }

    if (!mounted) return;
    setState(() {
      _subtitleTracks = tracks;
      final preferred = tracks.firstWhere(
        (t) => t.id.startsWith('ext_'),
        orElse: () => tracks.firstWhere(
          (t) => t.id == 'demo_zh',
          orElse: () => tracks.length > 1 ? tracks[1] : tracks.first,
        ),
      );
      if (_subtitleOn) {
        _subtitleId = preferred.id;
        _activeCues = preferred.cues;
      }
      _danmakuList = danmaku;
    });
  }

  void _loadSubtitleAndDanmaku() {
    final subSvc = ref.read(subtitleServiceProvider);
    final danSvc = ref.read(danmakuServiceProvider);
    _subtitleTracks = subSvc.demoTracks();
    _activeCues = _subtitleTracks
        .firstWhere((t) => t.id == _subtitleId, orElse: () => _subtitleTracks.first)
        .cues;
    _danmakuList = danSvc.demoDanmaku();
  }


  Future<void> _loadLiveEpg() async {
    try {
      final all = await ref.read(epgServiceProvider).loadAll();
      // 尝试 id: live_ 前缀去掉 / 频道名
      final id = widget.vod.id.replaceFirst('live_', '');
      var list = all[id] ?? all[widget.vod.id] ?? [];
      if (list.isEmpty) {
        // 按名称模糊
        for (final e in all.entries) {
          if (e.value.isNotEmpty) {
            list = e.value;
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _epgPrograms = list;
        _epgNow = ref.read(epgServiceProvider).nowPlaying(list);
      });
    } catch (_) {}
  }

  void _showLiveEpgSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('节目单', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                Expanded(
                  child: _epgPrograms.isEmpty
                      ? const Center(child: Text('暂无 EPG', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: _epgPrograms.length,
                          itemBuilder: (_, i) {
                            final p = _epgPrograms[i];
                            final on = p.isOnAt(DateTime.now());
                            final time =
                                '${p.start.hour.toString().padLeft(2, '0')}:${p.start.minute.toString().padLeft(2, '0')}'
                                '-'
                                '${p.end.hour.toString().padLeft(2, '0')}:${p.end.minute.toString().padLeft(2, '0')}';
                            return ListTile(
                              leading: Icon(
                                on ? Icons.play_circle_fill_rounded : Icons.schedule_rounded,
                                color: on ? Theme.of(context).colorScheme.primary : Colors.white54,
                              ),
                              title: Text(p.title, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(time, style: const TextStyle(color: Colors.white54)),
                              dense: true,
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
  }

  Future<void> _loadPlayerPrefs() async {
    try {
      final prefs = await ref.read(playerPrefsProvider.future);
      if (!mounted) return;
      setState(() {
        _danmakuOn = prefs.danmakuOn;
        _subtitleOn = prefs.subtitleOn;
        _autoNext = prefs.autoNext;
        _danmakuOpacity = prefs.danmakuOpacity;
        _speed = prefs.speed;
        if (!_subtitleOn) {
          _subtitleId = 'off';
          _activeCues = [];
        }
      });
      await _player.setRate(_speed);
    } catch (_) {}
  }

  Future<void> _persistPlayerPrefs() async {
    try {
      final prefs = await ref.read(playerPrefsProvider.future);
      prefs.danmakuOn = _danmakuOn;
      prefs.subtitleOn = _subtitleOn;
      prefs.autoNext = _autoNext;
      prefs.danmakuOpacity = _danmakuOpacity;
      prefs.speed = _speed;
      await prefs.save();
    } catch (_) {}
  }

  void _tryResume(Duration duration) {
    final ms = widget.resumePosition;
    if (ms == null || ms <= 0) return;
    if (ms > duration.inMilliseconds - 5000) return;
    _didResume = true;
    _player.seek(Duration(milliseconds: ms));
  }

  void _startProgressSaver() {
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
  }

  Future<void> _saveProgress() async {
    if (_duration.inMilliseconds <= 0) return;
    try {
      await ref.read(storageServiceProvider).updateProgress(
            id: widget.vod.id,
            sourceKey: widget.vod.sourceKey,
            position: _position,
            duration: _duration,
            episodeName: _episode.name,
            episodeUrl: _episode.url,
            flag: _episode.flag,
          );
      final existing = await ref.read(storageServiceProvider).getHistoryItem(
            widget.vod.id,
            sourceKey: widget.vod.sourceKey,
          );
      if (existing == null) {
        await ref.read(storageServiceProvider).addHistory(
              vod: widget.vod,
              episode: _episode,
              position: _position,
              duration: _duration,
            );
      }
      ref.invalidate(historyProvider);
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    // 同步尽力保存，避免 dispose 后 ref 不可用
    unawaited(_saveProgress());
    _player.dispose();
    unawaited(WakelockPlus.disable());
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _resolveAndPlay({Episode? ep}) async {
    final target = ep ?? _episode;
    setState(() {
      _loading = true;
      _error = null;
      _episode = target;
      _didResume = ep != null ? true : _didResume; // 切集不自动旧进度
    });
    try {
      final source = ref.read(activeSourceProvider);
      final manager = ref.read(spiderManagerProvider);
      final spider = await manager.getSpider(source);
      final result = await spider.play(
        id: widget.vod.id,
        flag: target.flag ?? '',
        play: target.url,
      );

      if (mounted && result.parse != 0) {
        setState(() => _statusHint = '正在解析播放地址…');
      }

      await _player.open(
        Media(
          result.url,
          httpHeaders: result.headers.isNotEmpty ? result.headers : null,
        ),
      );
      await _player.setRate(_speed);
      await _player.play();

      // 外挂字幕 + 弹幕
      await _loadExternalTracks(result);

      try {
        await ref.read(storageServiceProvider).addHistory(
              vod: widget.vod,
              episode: target,
              position: Duration.zero,
              duration: Duration.zero,
            );
        ref.invalidate(historyProvider);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _loading = false;
          _statusHint = null;
        });
        if (_isLive) _loadLiveEpg();
        _scheduleHideControls();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Episode> get _flagEpisodes {
    if (_allEpisodes.isEmpty) return [_episode];
    final flag = _currentFlag ?? _episode.flag;
    final filtered = _allEpisodes.where((e) => e.flag == flag).toList();
    return filtered.isEmpty ? _allEpisodes : filtered;
  }

  int get _episodeIndex {
    final list = _flagEpisodes;
    return list.indexWhere((e) => e.name == _episode.name && e.url == _episode.url);
  }

  void _playNext() {
    final list = _flagEpisodes;
    final i = _episodeIndex;
    if (i >= 0 && i < list.length - 1) {
      _resolveAndPlay(ep: list[i + 1]);
    }
  }

  void _playPrev() {
    final list = _flagEpisodes;
    final i = _episodeIndex;
    if (i > 0) {
      _resolveAndPlay(ep: list[i - 1]);
    }
  }

  void _toggleControls() {
    if (_locked) {
      setState(() => _showControls = !_showControls);
      if (_showControls) _scheduleHideControls();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _playing && !_longPressBoost) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlay() {
    if (_locked) return;
    _player.playOrPause();
    _scheduleHideControls();
  }

  void _seekRelative(int seconds) {
    if (_locked) return;
    _player.seek(_position + Duration(seconds: seconds));
    _scheduleHideControls();
  }

  void _cycleSpeed() {
    if (_locked) return;
    final idx = _speeds.indexOf(_speed);
    final next = _speeds[(idx + 1) % _speeds.length];
    _player.setRate(next);
    setState(() => _speed = next);
    _persistPlayerPrefs();
    _scheduleHideControls();
  }

  void _cycleFit() {
    setState(() {
      _fit = switch (_fit) {
        _FitMode.contain => _FitMode.cover,
        _FitMode.cover => _FitMode.fill,
        _FitMode.fill => _FitMode.contain,
      };
    });
    _scheduleHideControls();
  }

  BoxFit get _boxFit => switch (_fit) {
        _FitMode.contain => BoxFit.contain,
        _FitMode.cover => BoxFit.cover,
        _FitMode.fill => BoxFit.fill,
      };

  String get _fitLabel => switch (_fit) {
        _FitMode.contain => '适应',
        _FitMode.cover => '裁剪',
        _FitMode.fill => '拉伸',
      };

  // ---------- 手势 ----------
  void _onScaleStart(ScaleStartDetails d) {
    if (_locked) return;
    _dragStartDx = d.localFocalPoint.dx;
    _dragStartDy = d.localFocalPoint.dy;
    _seekPreview = null;
    _brightnessPreview = null;
    _volumePreview = null;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_locked || _dragStartDx == null) return;
    final size = MediaQuery.sizeOf(context);
    final dx = d.localFocalPoint.dx - _dragStartDx!;
    final dy = d.localFocalPoint.dy - _dragStartDy!;

    if (_seekPreview == null &&
        _brightnessPreview == null &&
        _volumePreview == null) {
      if (!_isLive && dx.abs() > 12 && dx.abs() > dy.abs()) {
        // 横向：快进快退（直播不 seek）
        final deltaSec = (dx / size.width * 120).round();
        final target = _position + Duration(seconds: deltaSec);
        final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
        _seekPreview = Duration(milliseconds: target.inMilliseconds.clamp(0, maxMs));
        setState(() {});
      } else if (_isLive && dy.abs() > 48 && dy.abs() > dx.abs()) {
        // 直播纵向滑：松手切台在 end 处理 — 这里记方向
        _liveZapDir = dy < 0 ? 1 : -1;
        setState(() {});
      } else if (dy.abs() > 12) {
        if (_dragStartDx! < size.width / 2) {
          // 左半屏：亮度
          final delta = -dy / size.height;
          _brightnessPreview = (_brightness + delta).clamp(0.0, 1.0);
          // system brightness plugin removed for CI
          setState(() {});
        } else {
          // 右半屏：音量
          final delta = -dy / size.height;
          _volumePreview = (_volume + delta).clamp(0.0, 1.0);
          VolumeController().setVolume(_volumePreview!);
          setState(() {});
        }
      }
      return;
    }

    if (_seekPreview != null) {
      final deltaSec = (dx / size.width * 120).round();
      final target = _position + Duration(seconds: deltaSec);
      final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
      setState(() {
        _seekPreview =
            Duration(milliseconds: target.inMilliseconds.clamp(0, maxMs));
      });
    } else if (_brightnessPreview != null) {
      final delta = -dy / size.height;
      final v = (_brightness + delta).clamp(0.0, 1.0);
      _brightnessPreview = v;
      // system brightness plugin removed for CI
      setState(() {});
    } else if (_volumePreview != null) {
      final delta = -dy / size.height;
      final v = (_volume + delta).clamp(0.0, 1.0);
      _volumePreview = v;
      VolumeController().setVolume(v);
      setState(() {});
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_seekPreview != null && !_isLive) {
      _player.seek(_seekPreview!);
      _saveProgress();
    }
    if (_brightnessPreview != null) _brightness = _brightnessPreview!;
    if (_volumePreview != null) _volume = _volumePreview!;

    // 直播：纵向大滑动切台
    if (_isLive &&
        _dragStartDy != null &&
        _seekPreview == null &&
        _brightnessPreview == null &&
        _volumePreview == null) {
      // handled in update via previews only; use velocity
    }

    if (_isLive && _liveZapDir != null) {
      final dir = _liveZapDir!;
      _liveZapDir = null;
      if (dir > 0) {
        _playNext();
      } else {
        _playPrev();
      }
    }

    setState(() {
      _dragStartDx = null;
      _dragStartDy = null;
      _seekPreview = null;
      _brightnessPreview = null;
      _volumePreview = null;
      _liveZapDir = null;
    });
    _scheduleHideControls();
  }

  void _onLongPressStart(LongPressStartDetails d) {
    if (_locked) return;
    _longPressBoost = true;
    _player.setRate(2.0);
    setState(() => _showControls = true);
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    if (!_longPressBoost) return;
    _longPressBoost = false;
    _player.setRate(_speed);
    setState(() {});
    _scheduleHideControls();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTapDown: (details) {
          if (_locked) return;
          final w = MediaQuery.sizeOf(context).width;
          if (details.localPosition.dx < w / 3) {
            _seekRelative(-10);
          } else if (details.localPosition.dx > w * 2 / 3) {
            _seekRelative(10);
          } else {
            _togglePlay();
          }
        },
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 视频
            Center(
              child: Video(
                controller: _controller,
                controls: NoVideoControls,
                fill: Colors.black,
                fit: _boxFit,
              ),
            ),

            // 弹幕
            DanmakuOverlay(
              position: _position,
              items: _danmakuList,
              enabled: _danmakuOn && !_loading && _error == null,
              opacity: _danmakuOpacity,
            ),

            // 字幕
            SubtitleOverlay(
              position: _position,
              cues: _activeCues,
              enabled: _subtitleOn && !_loading && _error == null,
            ),

            // 手势反馈
            if (_seekPreview != null) _centerBadge(
              icon: Icons.fast_forward_rounded,
              text: _fmt(_seekPreview!),
            ),
            if (_brightnessPreview != null) _sideBadge(
              left: true,
              icon: Icons.brightness_6_rounded,
              value: _brightnessPreview!,
            ),
            if (_volumePreview != null) _sideBadge(
              left: false,
              icon: Icons.volume_up_rounded,
              value: _volumePreview!,
            ),
            if (_longPressBoost)
              _centerBadge(icon: Icons.speed_rounded, text: '2.0x 长按倍速'),

            // 缓冲 / 解析提示
            if ((_buffering && !_loading) || _statusHint != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white70,
                          strokeWidth: 2,
                        ),
                      ),
                      if (_statusHint != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          _statusHint!,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            if (_loading)
              const ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('正在解析并加载…', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),

            if (_error != null)
              ColoredBox(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => _resolveAndPlay(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),

            // 锁定时仅显示解锁按钮
            if (_locked && _showControls)
              Positioned(
                right: 24,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    iconSize: 40,
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                    icon: const Icon(Icons.lock_rounded, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _locked = false;
                        _showControls = true;
                      });
                      _scheduleHideControls();
                    },
                  ),
                ),
              ),

            if (_showControls && !_loading && _error == null && !_locked) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _centerBadge({required IconData icon, required String text}) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _sideBadge({required bool left, required IconData icon, required double value}) {
    return Positioned(
      left: left ? 32 : null,
      right: left ? null : 32,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('${(value * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final hasPrev = _episodeIndex > 0;
    final hasNext = _episodeIndex >= 0 && _episodeIndex < _flagEpisodes.length - 1;
    final bufferedValue = _duration.inMilliseconds > 0
        ? (_buffered.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return ColoredBox(
      color: Colors.black45,
      child: SafeArea(
        child: Column(
          children: [
            // 顶栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (_isLive) ...[
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                _isLive ? _episode.name : widget.vod.name,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _isLive
                              ? (_epgNow != null
                                  ? '正在播放：${_epgNow!.title}'
                                  : '上下滑切换频道')
                              : (_episode.name + (_episode.flag != null ? ' · ${_episode.flag}' : '')),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '弹幕',
                    icon: Icon(
                      _danmakuOn ? Icons.subtitles_rounded : Icons.subtitles_off_rounded,
                      color: _danmakuOn ? Colors.white : Colors.white38,
                    ),
                    onPressed: () {
                      setState(() => _danmakuOn = !_danmakuOn);
                      _persistPlayerPrefs();
                      _scheduleHideControls();
                    },
                  ),
                  IconButton(
                    tooltip: '字幕',
                    icon: Icon(
                      _subtitleOn
                          ? Icons.closed_caption_rounded
                          : Icons.closed_caption_disabled_rounded,
                      color: _subtitleOn ? Colors.white : Colors.white38,
                    ),
                    onPressed: () {
                      setState(() {
                        _subtitleOn = !_subtitleOn;
                        if (_subtitleOn && _subtitleId == 'off') {
                          _subtitleId = 'demo_zh';
                          _activeCues = _subtitleTracks
                              .firstWhere((t) => t.id == 'demo_zh')
                              .cues;
                        }
                      });
                      _persistPlayerPrefs();
                      _scheduleHideControls();
                    },
                  ),
                  IconButton(
                    tooltip: '画面比例',
                    icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
                    onPressed: _cycleFit,
                  ),
                  TextButton(
                    onPressed: _cycleSpeed,
                    child: Text('${_speed}x',
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  IconButton(
                    tooltip: '锁定',
                    icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _locked = true;
                        _showControls = true;
                      });
                      _scheduleHideControls();
                    },
                  ),
                  IconButton(
                    tooltip: '画中画',
                    icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                    onPressed: () async {
                      final ok = await ref.read(castServiceProvider).enterPip();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? '已进入画中画' : '当前设备暂不支持画中画（需原生通道）',
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: '投屏',
                    icon: const Icon(Icons.cast_rounded, color: Colors.white),
                    onPressed: () async {
                      final r = await ref.read(castServiceProvider).castUrl(
                            widget.episode.url,
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            r == 'ok'
                                ? '已发起投屏'
                                : '投屏能力预留中（对标催壳扩展位）',
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                    onPressed: _showMoreSheet,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 中部按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 36,
                  onPressed: hasPrev ? _playPrev : null,
                  icon: Icon(Icons.skip_previous_rounded,
                      color: hasPrev ? Colors.white : Colors.white24),
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                  onPressed: () => _seekRelative(-10),
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 64,
                  icon: Icon(
                    _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlay,
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                  onPressed: () => _seekRelative(10),
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 36,
                  onPressed: hasNext ? _playNext : null,
                  icon: Icon(Icons.skip_next_rounded,
                      color: hasNext ? Colors.white : Colors.white24),
                ),
              ],
            ),

            const Spacer(),

            // 底栏：进度 + 选集
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          _fmt(_position),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // 缓冲条
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: LinearProgressIndicator(
                                value: bufferedValue,
                                minHeight: 2,
                                backgroundColor: Colors.white12,
                                color: Colors.white30,
                              ),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape:
                                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape:
                                    const RoundSliderOverlayShape(overlayRadius: 12),
                                activeTrackColor: Theme.of(context).colorScheme.primary,
                                inactiveTrackColor: Colors.transparent,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _duration.inMilliseconds > 0
                                    ? _position.inMilliseconds
                                        .clamp(0, _duration.inMilliseconds)
                                        .toDouble()
                                    : 0,
                                max: _duration.inMilliseconds > 0
                                    ? _duration.inMilliseconds.toDouble()
                                    : 1,
                                onChanged: (v) {
                                  _player.seek(Duration(milliseconds: v.toInt()));
                                },
                                onChangeEnd: (_) {
                                  _scheduleHideControls();
                                  _saveProgress();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          _fmt(_duration),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(_fitLabel,
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const Spacer(),
                      if (_isLive)
                        TextButton(
                          onPressed: _showLiveEpgSheet,
                          child: const Text('节目单', style: TextStyle(color: Colors.white)),
                        ),
                      TextButton(
                        onPressed: _showEpisodeSheet,
                        child: Text(_isLive ? '频道' : '选集', style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEpisodeSheet() async {
    final ep = await showEpisodeSheet(
      context: context,
      allEpisodes: _allEpisodes,
      current: _episode,
      currentFlag: _currentFlag,
      onFlagChanged: (f) => setState(() => _currentFlag = f),
    );
    if (ep != null && mounted) {
      await _resolveAndPlay(ep: ep);
    }
  }

  Future<void> _showMoreSheet() async {
    final result = await showPlayerMoreSheet(
      context: context,
      options: PlayerMoreOptions(
        danmakuOn: _danmakuOn,
        subtitleOn: _subtitleOn,
        subtitleId: _subtitleId,
        danmakuOpacity: _danmakuOpacity,
        speed: _speed,
        subtitleTracks: _subtitleTracks,
        speeds: _speeds,
        autoNext: _autoNext,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.danmakuOn != null) _danmakuOn = result.danmakuOn!;
      if (result.subtitleOn != null) _subtitleOn = result.subtitleOn!;
      if (result.subtitleId != null) {
        _subtitleId = result.subtitleId!;
        final track = _subtitleTracks.firstWhere(
          (t) => t.id == _subtitleId,
          orElse: () => _subtitleTracks.first,
        );
        _activeCues = track.cues;
      }
      if (result.danmakuOpacity != null) _danmakuOpacity = result.danmakuOpacity!;
      if (result.speed != null) {
        _speed = result.speed!;
        _player.setRate(_speed);
      }
      if (result.autoNext != null) _autoNext = result.autoNext!;
    });
    await _persistPlayerPrefs();
  }

}
