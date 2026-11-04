import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/widgets/glass_container.dart';
import '../../core/widgets/async_body.dart';
import '../../services/source_repo_service.dart';
import '../../services/source_service.dart';
import '../../services/spider/spider_manager.dart';

/// 源订阅仓库管理
class SourceRepoPage extends ConsumerStatefulWidget {
  const SourceRepoPage({super.key});

  @override
  ConsumerState<SourceRepoPage> createState() => _SourceRepoPageState();
}

class _SourceRepoPageState extends ConsumerState<SourceRepoPage> {
  bool _syncing = false;
  String? _status;

  Future<void> _addRepo() async {
    final nameC = TextEditingController();
    final urlC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加源仓库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '我的仓库',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlC,
              decoration: const InputDecoration(
                labelText: '地址',
                hintText: 'https://.../sources.json 或 demo://repo',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('添加')),
        ],
      ),
    );
    if (ok != true) return;
    final url = urlC.text.trim();
    final name = nameC.text.trim().isEmpty ? '源仓库' : nameC.text.trim();
    if (url.isEmpty) return;
    final repo = SourceRepo(
      id: 'repo_${url.hashCode.abs()}',
      name: name,
      url: url,
    );
    await ref.read(sourceRepoServiceProvider).addRepo(repo);
    ref.invalidate(sourceReposProvider);
  }

  Future<void> _sync(SourceRepo repo) async {
    setState(() {
      _syncing = true;
      _status = '正在同步 ${repo.name}…';
    });
    try {
      final result =
          await ref.read(sourceRepoServiceProvider).syncRepo(repo);
      ref.invalidate(sourceReposProvider);
      ref.invalidate(sourcesProvider);
      setState(() {
        _status =
            '同步完成：新增 ${result.added}，更新 ${result.updated}，共 ${result.total} 个源'
            '${result.message != null ? '（${result.message}）' : ''}';
      });
    } catch (e) {
      setState(() => _status = '同步失败: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _syncAll(List<SourceRepo> repos) async {
    for (final r in repos) {
      await _sync(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sourceReposProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('源订阅仓库'),
        actions: [
          IconButton(
            tooltip: '全部同步',
            icon: const Icon(Icons.sync_rounded),
            onPressed: _syncing
                ? null
                : () {
                    final list = ref.read(sourceReposProvider).valueOrNull ?? [];
                    if (list.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先添加仓库')),
                      );
                      return;
                    }
                    _syncAll(list);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _addRepo,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_status != null)
            MaterialBanner(
              content: Text(_status!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _status = null),
                  child: const Text('关闭'),
                ),
              ],
            ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(message: '$e'),
              data: (repos) {
                if (repos.isEmpty) {
                  return EmptyView(
                    message: '还没有订阅仓库',
                    icon: Icons.cloud_download_outlined,
                    actionLabel: '添加仓库',
                    onAction: _addRepo,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: repos.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == repos.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '支持格式：\n'
                          '• TVBox { "urls":[{"name","url"}] }\n'
                          '• 源数组 [{ "key","name","api","type" }]\n'
                          '• 演示：demo://repo',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    final r = repos[i];
                    return GlassCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.cloud_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(r.name),
                        subtitle: Text(
                          [
                            r.url,
                            if (r.lastSync != null)
                              '上次同步 ${r.lastSync!.month}/${r.lastSync!.day} ${r.lastSync!.hour}:${r.lastSync!.minute.toString().padLeft(2, '0')} · ${r.lastCount} 源',
                          ].join('\n'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: r.lastSync != null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '同步',
                              icon: _syncing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync_rounded),
                              onPressed: _syncing ? null : () => _sync(r),
                            ),
                            IconButton(
                              tooltip: '删除',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                await ref
                                    .read(sourceRepoServiceProvider)
                                    .removeRepo(r.id);
                                ref.invalidate(sourceReposProvider);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 一键加演示仓库并同步
          final repo = const SourceRepo(
            id: 'demo_repo',
            name: '演示仓库',
            url: 'demo://repo',
          );
          await ref.read(sourceRepoServiceProvider).addRepo(repo);
          ref.invalidate(sourceReposProvider);
          await _sync(repo);
        },
        icon: const Icon(Icons.science_rounded),
        label: const Text('演示仓库'),
      ),
    );
  }
}
