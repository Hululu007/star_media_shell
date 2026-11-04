import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/widgets/glass_container.dart';
import '../../models/source.dart';
import '../../services/source_service.dart';
import '../../services/spider/spider_manager.dart';

class SourcePage extends ConsumerWidget {
  const SourcePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(sourcesProvider);
    final active = ref.watch(activeSourceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('源管理'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/source/repo'),
            icon: const Icon(Icons.cloud_download_outlined, size: 18),
            label: const Text('仓库'),
          ),
        ],
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (sources) {
          if (sources.isEmpty) {
            return const Center(child: Text('暂无源，点击右上角添加'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              final isActive = source.key == active.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  onTap: () async {
                    ref.read(activeSourceProvider.notifier).state = source;
                    final service = ref.read(sourceServiceProvider);
                    await service.saveActiveKey(source.key);
                    // 刷新首页
                    ref.invalidate(homeDataProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已切换到「${source.name}」')),
                      );
                    }
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        _iconForType(source.type),
                        color: isActive ? Colors.white : null,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      source.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      '${source.type.name.toUpperCase()}  ·  ${source.api}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isActive
                        ? Icon(Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary)
                        : IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _confirmDelete(context, ref, source),
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(SourceType type) {
    return switch (type) {
      SourceType.drpy => Icons.javascript,
      SourceType.python => Icons.code,
      SourceType.json => Icons.api,
      _ => Icons.source,
    };
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final apiCtrl = TextEditingController();
    var type = SourceType.json;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('添加源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiCtrl,
                decoration: const InputDecoration(labelText: '接口地址 / 规则'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SourceType>(
                value: type,
                decoration: const InputDecoration(labelText: '类型'),
                items: SourceType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
                onChanged: (v) => setState(() => type = v ?? SourceType.json),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('添加')),
          ],
        ),
      ),
    );

    if (ok == true && nameCtrl.text.isNotEmpty && apiCtrl.text.isNotEmpty) {
      final source = Source(
        key: const Uuid().v4().substring(0, 8),
        name: nameCtrl.text.trim(),
        api: apiCtrl.text.trim(),
        type: type,
      );
      try {
        await ref.read(sourceServiceProvider).addSource(source);
        ref.invalidate(sourcesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Source source) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除源'),
        content: Text('确定删除「${source.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(sourceServiceProvider).removeSource(source.key);
      ref.invalidate(sourcesProvider);
    }
  }
}
