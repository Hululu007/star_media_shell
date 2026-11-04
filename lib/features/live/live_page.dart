import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/widgets/glass_container.dart';
import '../../core/widgets/async_body.dart';
import '../../models/epg.dart';
import '../../models/live_channel.dart';
import '../../models/vod.dart';
import '../../services/epg_service.dart';
import '../../services/live_favorite_service.dart';
import '../../services/live_service.dart';

class LivePage extends ConsumerStatefulWidget {
  const LivePage({super.key});

  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

class _LivePageState extends ConsumerState<LivePage> {
  bool _favOnly = false;

  Future<void> _editUrl() async {
    final svc = ref.read(liveServiceProvider);
    final current = await svc.getSavedUrl() ?? '';
    final controller = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('直播源 m3u 地址'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/tv.m3u',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await svc.saveUrl('');
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('恢复演示'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final v = controller.text.trim();
      if (v.isNotEmpty) await svc.saveUrl(v);
      ref.invalidate(liveChannelsAsyncProvider);
    }
  }

  void _showEpg(LiveChannel c, List<EpgProgram> programs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '${c.name} · 节目单',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Expanded(
                  child: programs.isEmpty
                      ? const Center(child: Text('暂无 EPG'))
                      : ListView.builder(
                          itemCount: programs.length,
                          itemBuilder: (_, i) {
                            final p = programs[i];
                            final on = p.isOnAt(DateTime.now());
                            final time =
                                '${p.start.hour.toString().padLeft(2, '0')}:${p.start.minute.toString().padLeft(2, '0')}'
                                ' - '
                                '${p.end.hour.toString().padLeft(2, '0')}:${p.end.minute.toString().padLeft(2, '0')}';
                            return ListTile(
                              leading: Icon(
                                on ? Icons.play_circle_fill_rounded : Icons.schedule_rounded,
                                color: on ? Theme.of(ctx).colorScheme.primary : null,
                              ),
                              title: Text(p.title),
                              subtitle: Text(time),
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

  void _play(LiveChannel c, List<LiveChannel> groupChannels) {
    final vod = Vod(
      id: 'live_${c.id}',
      name: c.name,
      sourceKey: 'live',
      type: '直播',
      remarks: '直播',
    );
    final ep = Episode(name: c.name, url: c.url, flag: '直播');
    // 同组频道用于播放器内上下切台
    final playlist = groupChannels
        .map((ch) => Episode(name: ch.name, url: ch.url, flag: '直播'))
        .toList();
    context.push('/player', extra: {
      'vod': vod,
      'episode': ep,
      'playlist': playlist,
      'isLive': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(liveChannelsAsyncProvider);
    final favAsync = ref.watch(liveFavoriteIdsProvider);
    final epgAsync = ref.watch(epgAllProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('直播'),
        actions: [
          IconButton(
            tooltip: _favOnly ? '全部频道' : '仅看收藏',
            icon: Icon(_favOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded),
            onPressed: () => setState(() => _favOnly = !_favOnly),
          ),
          IconButton(
            tooltip: '订阅 m3u',
            icon: const Icon(Icons.link_rounded),
            onPressed: _editUrl,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(liveChannelsAsyncProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(liveChannelsAsyncProvider),
        ),
        data: (channels) {
          final favIds = favAsync.valueOrNull ?? {};
          final epgMap = epgAsync.valueOrNull ?? {};
          var list = channels;
          if (_favOnly) {
            list = channels.where((c) => favIds.contains(c.id)).toList();
          }
          if (list.isEmpty) {
            return EmptyView(
              message: _favOnly ? '还没有收藏频道' : '暂无频道，请订阅 m3u',
              icon: Icons.live_tv_outlined,
              actionLabel: _favOnly ? null : '添加地址',
              onAction: _favOnly ? null : _editUrl,
            );
          }
          final groups = <String>{for (final c in list) c.group}.toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                  child: Text(
                    g,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                ...list.where((c) => c.group == g).map((c) {
                  final isFav = favIds.contains(c.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      onTap: () => _play(c, list.where((x) => x.group == c.group).toList()),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.live_tv_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(c.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          () {
                            final programs = epgMap[c.id] ?? [];
                            final now = ref.read(epgServiceProvider).nowPlaying(programs);
                            if (now != null) {
                              return '${c.group} · 正在播放：${now.title}';
                            }
                            return c.group;
                          }(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onLongPress: () => _showEpg(c, epgMap[c.id] ?? []),
                        trailing: IconButton(
                          icon: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFav ? Colors.redAccent : null,
                          ),
                          onPressed: () async {
                            await ref
                                .read(liveFavoriteServiceProvider)
                                .toggle(c.id);
                            ref.invalidate(liveFavoriteIdsProvider);
                          },
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}
