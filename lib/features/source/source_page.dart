import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/source.dart';
import '../../services/source_service.dart';
import '../../services/spider/spider_manager.dart';

/// 资源页 — 按原版布局与交互
class SourcePage extends ConsumerStatefulWidget {
  const SourcePage({super.key});

  @override
  ConsumerState<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends ConsumerState<SourcePage> {
  final _query = TextEditingController();
  bool _searchOpen = false;
  bool _selectMode = false;
  final _selected = <String>{};
  /// -2 测速中, -1 失败, >=0 结果
  final Map<String, int> _latency = {};
  String _typeFilter = 'all';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Source> _filter(List<Source> all) {
    final q = _query.text.trim().toLowerCase();
    return all.where((s) {
      if (_typeFilter != 'all' && s.type.name != _typeFilter) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.api.toLowerCase().contains(q) ||
          s.type.name.contains(q) ||
          s.key.toLowerCase().contains(q);
    }).toList();
  }

  String _timeAgo(DateTime? t) {
    if (t == null) return '未使用';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '刚刚';
    if (d.inHours < 1) return '${d.inMinutes} 分钟前';
    if (d.inHours < 24) return '${d.inHours} 小时前';
    if (d.inDays < 30) return '${d.inDays} 天前';
    return '${t.month}/${t.day}';
  }

  Future<void> _probe(Source s) async {
    setState(() => _latency[s.key] = -2);
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.tryParse(s.api);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        final updated = s.copyWith(lastLatencyMs: 0);
        await ref.read(sourceServiceProvider).updateSource(updated);
        if (mounted) setState(() => _latency[s.key] = 0);
        ref.invalidate(sourcesProvider);
        return;
      }
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        validateStatus: (_) => true,
        headers: {'User-Agent': 'Mozilla/5.0'},
      ));
      try {
        await dio.head(s.api);
      } catch (_) {
        await dio.get(s.api);
      }
      sw.stop();
      final ms = sw.elapsedMilliseconds;
      final updated = s.copyWith(lastLatencyMs: ms);
      await ref.read(sourceServiceProvider).updateSource(updated);
      if (mounted) setState(() => _latency[s.key] = ms);
      ref.invalidate(sourcesProvider);
    } catch (_) {
      if (mounted) setState(() => _latency[s.key] = -1);
    }
  }

  Future<void> _activate(Source source) async {
    final updated = source.copyWith(lastUsedAt: DateTime.now());
    try {
      await ref.read(sourceServiceProvider).updateSource(updated);
    } catch (_) {
      // 可能是刚导入尚未写入完成
      try {
        await ref.read(sourceServiceProvider).addSource(updated);
      } catch (_) {}
    }
    ref.read(activeSourceProvider.notifier).state = updated;
    await ref.read(sourceServiceProvider).saveActiveKey(source.key);
    ref.invalidate(homeDataProvider);
    ref.invalidate(sourcesProvider);
    if (mounted) {
      final tip = source.canLoadHome
          ? '已切换到「${source.name}」'
          : '已切换到「${source.name}」（CSP/Jar 站，首页可能无数据，需 jar 运行时）';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tip)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(sourcesProvider);
    final active = ref.watch(activeSourceProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶栏：标题 + 工具胶囊
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Text(
                    '资源',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _IconBtn(
                          icon: Icons.tune_rounded,
                          onTap: () => _showFilterSheet(context),
                        ),
                        _IconBtn(
                          icon: _searchOpen
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          onTap: () => setState(() {
                            _searchOpen = !_searchOpen;
                            if (!_searchOpen) _query.clear();
                          }),
                        ),
                        _IconBtn(
                          icon: Icons.add_rounded,
                          onTap: () => context.push('/source/add'),
                        ),
                        _IconBtn(
                          icon: _selectMode
                              ? Icons.check_circle_rounded
                              : Icons.check_circle_outline_rounded,
                          onTap: () => setState(() {
                            _selectMode = !_selectMode;
                            _selected.clear();
                          }),
                        ),
                        _IconBtn(
                          icon: Icons.graphic_eq_rounded,
                          onTap: () {
                            final list =
                                _filter(sourcesAsync.valueOrNull ?? []);
                            for (final s in list) {
                              _probe(s);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_searchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索资源名称、地址或类型',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: TextButton(
                      onPressed: () => setState(() {
                        _searchOpen = false;
                        _query.clear();
                      }),
                      child: Text('取消',
                          style: TextStyle(
                              color: cs.error, fontWeight: FontWeight.w600)),
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: sourcesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e')),
                data: (all) {
                  final list = _filter(all);
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 56, color: cs.outline),
                          const SizedBox(height: 12),
                          const Text('暂无资源'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => context.push('/source/add'),
                            icon: const Icon(Icons.add),
                            label: const Text('添加资源'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final s = list[i];
                      final isActive = s.key == active.key;
                      final lat = _latency[s.key] ?? s.lastLatencyMs;
                      return _ResourceCard(
                        source: s,
                        isActive: isActive,
                        latency: lat,
                        timeLabel: _timeAgo(s.lastUsedAt),
                        selectMode: _selectMode,
                        selected: _selected.contains(s.key),
                        onTap: () {
                          if (_selectMode) {
                            setState(() {
                              if (!_selected.add(s.key)) {
                                _selected.remove(s.key);
                              }
                            });
                          } else {
                            _activate(s);
                          }
                        },
                        onMore: () => _more(context, s),
                        onProbe: () => _probe(s),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selectMode && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.errorContainer,
                    foregroundColor: cs.onErrorContainer,
                  ),
                  onPressed: () async {
                    final svc = ref.read(sourceServiceProvider);
                    for (final k in _selected) {
                      await svc.removeSource(k);
                    }
                    setState(() {
                      _selected.clear();
                      _selectMode = false;
                    });
                    ref.invalidate(sourcesProvider);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text('删除 ${_selected.length} 项'),
                ),
              ),
            )
          : null,
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final items = <(String, String)>[
          ('all', '全部'),
          ...SourceType.values.map((e) => (e.name, e.name)),
        ];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('筛选类型',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              for (final (id, label) in items)
                ListTile(
                  title: Text(label),
                  trailing: _typeFilter == id
                      ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() => _typeFilter = id);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _more(BuildContext context, Source s) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('测速'),
              onTap: () {
                Navigator.pop(ctx);
                _probe(s);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('设为当前使用'),
              onTap: () {
                Navigator.pop(ctx);
                _activate(s);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(sourceServiceProvider).removeSource(s.key);
                ref.invalidate(sourcesProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20),
      onPressed: onTap,
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.source,
    required this.isActive,
    required this.latency,
    required this.timeLabel,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onMore,
    required this.onProbe,
  });

  final Source source;
  final bool isActive;
  final int? latency;
  final String timeLabel;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final VoidCallback onProbe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String latLabel;
    Color latColor;
    if (latency == null) {
      latLabel = '测速';
      latColor = cs.onSurfaceVariant;
    } else if (latency == -2) {
      latLabel = '…';
      latColor = cs.primary;
    } else if (latency == -1) {
      latLabel = '超时';
      latColor = cs.error;
    } else if (latency == 0) {
      latLabel = '本地';
      latColor = const Color(0xFF16A34A);
    } else {
      latLabel = '${latency}ms';
      latColor = latency! < 400
          ? const Color(0xFF16A34A)
          : (latency! < 1000 ? Colors.orange : cs.error);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isActive ? cs.primary : cs.outlineVariant.withOpacity(0.35),
            width: isActive ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onMore,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (selectMode) ...[
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected ? cs.primary : cs.outline,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.movie_creation_outlined,
                          color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (isActive)
                            Text(
                              '当前使用',
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz_rounded),
                      onPressed: onMore,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onProbe,
                      child: Text(
                        latLabel,
                        style: TextStyle(
                          color: latColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '  ·  $timeLabel',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.layers_outlined,
                        size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${source.siteCount > 0 ? source.siteCount : (source.enabled ? 1 : 0)}',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.search,
                        size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      source.searchable ? '可搜' : '—',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
