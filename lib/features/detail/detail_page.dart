import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/widgets/glass_container.dart';
import '../../models/vod.dart';
import '../../services/spider/spider_manager.dart';
import '../../services/storage_service.dart';

class DetailPage extends ConsumerWidget {
  const DetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(detailProvider(id));

    return Scaffold(
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (vod) => _DetailBody(vod: vod),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.vod});

  final Vod vod;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _isFav = false;
  HistoryItem? _history;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final storage = ref.read(storageServiceProvider);
    final fav = await storage.isFavorite(
      widget.vod.id,
      sourceKey: widget.vod.sourceKey,
    );
    final hist = await storage.getHistoryItem(
      widget.vod.id,
      sourceKey: widget.vod.sourceKey,
    );
    if (mounted) {
      setState(() {
        _isFav = fav;
        _history = hist;
      });
    }
  }

  Future<void> _toggleFav() async {
    await ref.read(storageServiceProvider).toggleFavorite(widget.vod);
    ref.invalidate(favoritesProvider);
    await _loadMeta();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFav ? '已收藏' : '已取消收藏')),
      );
    }
  }

  void _playEpisode(Episode ep, {int? resumeMs}) {
    context.push('/player', extra: {
      'vod': widget.vod,
      'episode': ep,
      if (resumeMs != null && resumeMs > 0) 'resumePosition': resumeMs,
    });
  }

  void _continueWatching() {
    final h = _history;
    if (h == null) return;
    final ep = Episode(
      name: h.episodeName,
      url: h.episodeUrl,
      flag: h.flag,
    );
    _playEpisode(ep, resumeMs: h.positionMs);
  }

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final vod = widget.vod;
    final flags = <String, List<Episode>>{};
    for (final ep in vod.episodes) {
      final flag = ep.flag ?? '默认';
      flags.putIfAbsent(flag, () => []).add(ep);
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          actions: [
            IconButton(
              icon: Icon(
                _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFav ? Colors.redAccent : null,
              ),
              onPressed: _toggleFav,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            title: Text(vod.name, style: const TextStyle(fontSize: 16)),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (vod.pic != null && vod.pic!.startsWith('http'))
                  CachedNetworkImage(
                    imageUrl: vod.pic!,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (vod.year != null) _InfoChip(label: vod.year!),
                    if (vod.area != null) _InfoChip(label: vod.area!),
                    if (vod.type != null) _InfoChip(label: vod.type!),
                  ],
                ),
                const SizedBox(height: 12),
                if (vod.director != null)
                  Text('导演：${vod.director}', style: Theme.of(context).textTheme.bodyMedium),
                if (vod.actor != null) ...[
                  const SizedBox(height: 4),
                  Text('主演：${vod.actor}', style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (vod.des != null) ...[
                  const SizedBox(height: 12),
                  Text(vod.des!, style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (flags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${flags.length} 条线路 · ${vod.episodes.length} 集',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],

                // 继续播放
                if (_history != null && _history!.positionMs > 3000) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    onTap: _continueWatching,
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_fill_rounded,
                            color: Theme.of(context).colorScheme.primary, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '继续播放 · ${_history!.episodeName}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '已观看 ${_fmtMs(_history!.positionMs)}'
                                '${_history!.durationMs > 0 ? ' / ${_fmtMs(_history!.durationMs)}' : ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (_history!.durationMs > 0) ...[
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: _history!.progress,
                                    minHeight: 3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ...flags.entries.map((entry) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  FocusTraversalGroup(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.map((ep) {
                        final isCurrent = _history != null &&
                            _history!.episodeName == ep.name &&
                            (_history!.flag == null || _history!.flag == ep.flag);
                        return Focus(
                          child: Builder(
                            builder: (context) {
                              final focused = Focus.of(context).hasFocus;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: focused
                                      ? Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: ActionChip(
                                  avatar: isCurrent
                                      ? Icon(Icons.play_arrow_rounded,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)
                                      : null,
                                  label: Text(ep.name),
                                  onPressed: () => _playEpisode(ep),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      borderRadius: 8,
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
