import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/storage_service.dart';
import '../home/widgets/poster_card.dart';

class FavoritePage extends ConsumerWidget {
  const FavoritePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏'),
        actions: [
          if (favAsync.valueOrNull?.isNotEmpty == true)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('清空收藏'),
                    content: const Text('确定清空全部收藏吗？'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('清空')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(storageServiceProvider).saveFavorites([]);
                  ref.invalidate(favoritesProvider);
                }
              },
              child: const Text('清空'),
            ),
        ],
      ),
      body: favAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border_rounded,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text('还没有收藏',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('在详情页点击收藏即可添加',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.65,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final vod = list[i];
              return PosterCard(
                vod: vod,
                trailing: IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.favorite_rounded,
                      color: Colors.redAccent),
                  onPressed: () async {
                    await ref.read(storageServiceProvider).removeFavorite(
                          vod.id,
                          sourceKey: vod.sourceKey,
                        );
                    ref.invalidate(favoritesProvider);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
