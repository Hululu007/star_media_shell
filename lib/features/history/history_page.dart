import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/widgets/glass_container.dart';
import '../../models/vod.dart';
import '../../services/storage_service.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史'),
        actions: [
          if (historyAsync.valueOrNull?.isNotEmpty == true)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('清空历史'),
                    content: const Text('确定清空全部观看历史吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(storageServiceProvider).clearHistory();
                  ref.invalidate(historyProvider);
                }
              },
              child: const Text('清空'),
            ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text('暂无观看记录', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('播放影片后会自动记录进度', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final item = list[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  onTap: () {
                    // 有进度则直接续播，否则进详情
                    if (item.positionMs > 3000 && item.episodeUrl.isNotEmpty) {
                      context.push('/player', extra: {
                        'vod': item.vod,
                        'episode': Episode(
                          name: item.episodeName,
                          url: item.episodeUrl,
                          flag: item.flag,
                        ),
                        'resumePosition': item.positionMs,
                      });
                    } else {
                      context.push('/detail/${item.vod.id}');
                    }
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(Icons.play_arrow_rounded,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(item.vod.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.episodeName}${item.flag != null ? ' · ${item.flag}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.durationMs > 0) ...[
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: item.progress,
                              minHeight: 3,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () async {
                        await ref.read(storageServiceProvider).removeHistory(
                              item.vod.id,
                              sourceKey: item.vod.sourceKey,
                            );
                        ref.invalidate(historyProvider);
                      },
                    ),
                    isThreeLine: item.durationMs > 0,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
