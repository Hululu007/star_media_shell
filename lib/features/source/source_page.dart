import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/source.dart';
import '../../services/source_service.dart';
import '../../services/spider/spider_manager.dart';

/// 资源页（对标原版：搜索/筛选/卡片延迟/站点量）
class SourcePage extends ConsumerStatefulWidget {
  const SourcePage({super.key});

  @override
  ConsumerState<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends ConsumerState<SourcePage> {
  final _query = TextEditingController();
  bool _searching = false;
  bool _selectMode = false;
  final _selected = <String>{};
  /// key -> latency ms；null=测中；-1=失败
  final Map<String, int?> _latency = {};
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
          s.type.name.toLowerCase().contains(q) ||
          s.key.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _probe(Source s) async {
    setState(() => _latency[s.key] = -2);
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.tryParse(s.api);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
        // 非 http：本地/协议源，标记为 0
        if (mounted) setState(() => _latency[s.key] = 0);
        return;
      }
      await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        validateStatus: (_) => true,
      )).head(s.api);
      sw.stop();
      if (mounted) setState(() => _latency[s.key] = sw.elapsedMilliseconds);
    } catch (_) {
      try {
        await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          validateStatus: (_) => true,
        )).get(s.api);
        sw.stop();
        if (mounted) setState(() => _latency[s.key] = sw.elapsedMilliseconds);
      } catch (_) {
        if (mounted) setState(() => _latency[s.key] = -1);
      }
    }
  }

  Future<void> _probeAll(List<Source> list) async {
    for (final s in list) {
      await _probe(s);
    }
  }

  Future<void> _activate(Source source) async {
    ref.read(activeSourceProvider.notifier).state = source;
    await ref.read(sourceServiceProvider).saveActiveKey(source.key);
    ref.invalidate(homeDataProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到「${source.name}」')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(sourcesProvider);
    final active = ref.watch(activeSourceProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Text('资源',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  _ToolPill(
                    children: [
                      IconButton(
                        tooltip: '类型筛选',
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        onPressed: () => _showFilter(context),
                      ),
                      IconButton(
                        tooltip: '搜索',
                        icon: Icon(
                          _searching ? Icons.close_rounded : Icons.search_rounded,
                          size: 20,
                        ),
                        onPressed: () => setState(() {
                          _searching = !_searching;
                          if (!_searching) _query.clear();
                        }),
                      ),
                      IconButton(
                        tooltip: '添加',
                        icon: const Icon(Icons.add_rounded, size: 22),
                        onPressed: () => context.push('/source/add'),
                      ),
                      IconButton(
                        tooltip: '多选',
                        icon: Icon(
                          _selectMode
                              ? Icons.check_circle_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 20,
                        ),
                        onPressed: () => setState(() {
                          _selectMode = !_selectMode;
                          _selected.clear();
                        }),
                      ),
                      IconButton(
                        tooltip: '测速',
                        icon: const Icon(Icons.graphic_eq_rounded, size: 20),
                        onPressed: () {
                          final list = sourcesAsync.valueOrNull ?? [];
                          _probeAll(_filter(list));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_searching)
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
                        _searching = false;
                        _query.clear();
                      }),
                      child: Text('取消',
                          style: TextStyle(color: cs.error)),
                    ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
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
                          const Text('暂无资源'),
                          const SizedBox(height: 12),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      final isActive = s.key == active.key;
                      final lat = _latency[s.key];
                      return _SourceCard(
                        source: s,
                        isActive: isActive,
                        latencyMs: lat,
                        selectMode: _selectMode,
                        selected: _selected.contains(s.key),
                        onSelect: () {
                          setState(() {
                            if (_selected.contains(s.key)) {
                              _selected.remove(s.key);
                            } else {
                              _selected.add(s.key);
                            }
                          });
                        },
                        onTap: () {
                          if (_selectMode) {
                            setState(() {
                              if (_selected.contains(s.key)) {
                                _selected.remove(s.key);
                              } else {
                                _selected.add(s.key);
                              }
                            });
                          } else {
                            _activate(s);
                          }
                        },
                        onLongPress: () => _showMore(context, s),
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
                padding: const EdgeInsets.all(12),
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final svc = ref.read(sourceServiceProvider);
                    for (final k in _selected.toList()) {
                      await svc.removeSource(k);
                    }
                    _selected.clear();
                    _selectMode = false;
                    ref.invalidate(sourcesProvider);
                    setState(() {});
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text('删除 ${_selected.length} 项'),
                ),
              ),
            )
          : null,
    );
  }

  void _showFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final types = ['all', ...SourceType.values.map((e) => e.name)];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('按类型筛选')),
              for (final t in types)
                ListTile(
                  title: Text(t == 'all' ? '全部' : t),
                  trailing: _typeFilter == t
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() => _typeFilter = t);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showMore(BuildContext context, Source s) {
    showModalBottomSheet(
      context: context,
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
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('设为当前'),
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

class _ToolPill extends StatelessWidget {
  const _ToolPill({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.7),
      borderRadius: BorderRadius.circular(24),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.isActive,
    required this.latencyMs,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onSelect,
    required this.onProbe,
  });

  final Source source;
  final bool isActive;
  final int? latencyMs;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSelect;
  final VoidCallback onProbe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final String latText;
    final Color latColor;
    if (latencyMs == null) {
      latText = '点击测速';
      latColor = cs.onSurfaceVariant;
    } else if (latencyMs == -2) {
      latText = '测速中';
      latColor = cs.primary;
    } else if (latencyMs == -1) {
      latText = '超时';
      latColor = cs.error;
    } else if (latencyMs == 0) {
      latText = '本地';
      latColor = Colors.green;
    } else {
      latText = '${latencyMs}ms';
      latColor = latencyMs! < 300
          ? Colors.green
          : (latencyMs! < 800 ? Colors.orange : cs.error);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surface,
        elevation: isActive ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isActive
              ? BorderSide(color: cs.primary, width: 1.5)
              : BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (selectMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: selected ? cs.primary : cs.outline,
                        ),
                      ),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: cs.primaryContainer,
                      child: Icon(_icon(source.type),
                          size: 18, color: cs.primary),
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
                                fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          if (isActive)
                            Text('当前使用',
                                style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: onLongPress,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onProbe,
                      child: Text(
                        latText,
                        style: TextStyle(
                          color: latColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      source.type.name,
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const Spacer(),
                    Icon(Icons.layers_outlined,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      source.enabled ? '开' : '关',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.search,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      source.searchable ? '可搜' : '不可搜',
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

  IconData _icon(SourceType t) {
    switch (t) {
      case SourceType.drpy:
        return Icons.javascript;
      case SourceType.python:
        return Icons.code;
      case SourceType.json:
        return Icons.api;
      default:
        return Icons.movie_outlined;
    }
  }
}
