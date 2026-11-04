import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/theme/widgets/glass_container.dart';
import '../../core/widgets/async_body.dart';
import '../../models/source.dart';
import '../../models/vod.dart';
import '../../services/paging.dart';
import '../../services/rank_service.dart';
import '../../services/source_service.dart';
import '../../services/announcement_service.dart';
import '../../services/storage_service.dart';
import '../../services/spider/spider_manager.dart';
import 'widgets/filter_bar.dart';
import 'widgets/focusable_row_scope.dart';
import 'widgets/hero_banner.dart';
import 'widgets/poster_card.dart';
import 'widgets/vod_row.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _selectedTypeId;
  final Map<String, String> _selectedFilters = {};
  Map<String, List<String>> _filterGroups = demoFilters();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureActiveSource();
      if (mounted) await showAnnouncementIfNeeded(context, ref);
    });
  }

  String _encodeFilters(Map<String, String> map) {
    // 去掉「全部」
    final cleaned = <String, String>{};
    map.forEach((k, v) {
      if (v.isNotEmpty && v != '全部') cleaned[k] = v;
    });
    if (cleaned.isEmpty) return '';
    // 简单 query：类型=动作&年份=2024
    return cleaned.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  Future<void> _ensureActiveSource() async {
    try {
      final list = await ref.read(sourcesProvider.future);
      if (list.isEmpty || !mounted) return;
      final active = ref.read(activeSourceProvider);
      if (list.every((s) => s.key != active.key)) {
        ref.read(activeSourceProvider.notifier).state = list.first;
        ref.invalidate(homeDataProvider);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final homeAsync = ref.watch(homeDataProvider);
    final source = ref.watch(activeSourceProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeDataProvider);
          ref.invalidate(hotRankProvider);
          ref.invalidate(historyProvider);
          await ref.read(homeDataProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('星辰影音'),
                  Text(
                    source.name,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => context.push('/search'),
                ),
                IconButton(
                  icon: Icon(
                    themeState.themeMode == ThemeMode.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                  onPressed: () {
                    ref.read(themeControllerProvider.notifier).cycleThemeMode();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.source_rounded),
                  tooltip: '源管理',
                  onPressed: () => context.push('/source'),
                  onLongPress: _showQuickSource,
                ),
                const SizedBox(width: 4),
              ],
            ),

            // 分类芯片
            homeAsync.when(
              loading: () => SliverToBoxAdapter(child: _CategorySkeleton()),
              error: (e, _) => SliverToBoxAdapter(
                child: ErrorView(
                  message: '$e',
                  onRetry: () => ref.invalidate(homeDataProvider),
                ),
              ),
              data: (result) => SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: result.classes.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        final sel = _selectedTypeId == null;
                        return FilterChip(
                          label: const Text('首页'),
                          selected: sel,
                          onSelected: (_) => setState(() => _selectedTypeId = null),
                        );
                      }
                      final cat = result.classes[i - 1];
                      final sel = _selectedTypeId == cat.typeId;
                      return FilterChip(
                        label: Text(cat.typeName),
                        selected: sel,
                        onSelected: (_) =>
                            setState(() => _selectedTypeId = cat.typeId),
                      );
                    },
                  ),
                ),
              ),
            ),

            // 内容
            if (_selectedTypeId == null)
              ..._buildHomeFeed(homeAsync)
            else ...[
              SliverToBoxAdapter(
                child: FilterBar(
                  groups: _filterGroups,
                  selected: {
                    for (final e in _filterGroups.entries)
                      e.key: _selectedFilters[e.key] ?? (e.value.isNotEmpty ? e.value.first : ''),
                  },
                  onChanged: (g, v) {
                    setState(() => _selectedFilters[g] = v);
                  },
                ),
              ),
              _CategoryGrid(
                typeId: _selectedTypeId!,
                filterKey: _encodeFilters(_selectedFilters),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }


  Future<void> _showQuickSource() async {
    final list = ref.read(sourcesProvider).valueOrNull;
    if (list == null || list.isEmpty) {
      if (mounted) context.push('/source');
      return;
    }
    final current = ref.read(activeSourceProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '快捷切源',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              ...list.map((s) {
                final sel = s.key == current.key;
                return ListTile(
                  leading: Icon(
                    sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: sel ? Theme.of(ctx).colorScheme.primary : null,
                  ),
                  title: Text(s.name),
                  subtitle: Text(s.type.name),
                  onTap: () => Navigator.pop(ctx, s.key),
                );
              }),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('源管理…'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/source');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    Source? match;
    for (final s in list) {
      if (s.key == selected) match = s;
    }
    if (match == null) return;
    ref.read(activeSourceProvider.notifier).state = match;
    await ref.read(sourceServiceProvider).saveActiveKey(match.key);
    ref.invalidate(homeDataProvider);
  }

  List<Widget> _buildHomeFeed(AsyncValue homeAsync) {
    return homeAsync.when(
      loading: () => [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const PosterGridSkeleton(count: 6),
      ],
      error: (_, __) => [const SliverToBoxAdapter(child: SizedBox.shrink())],
      data: (result) {
        final list = result.list as List<Vod>;
        final classes = result.classes;
        // 若源返回 filters，转成筛选条（对标催壳）
        final f = result.filters;
        if (f.isNotEmpty) {
          final parsed = <String, List<String>>{};
          f.forEach((k, v) {
            if (v is List) {
              parsed[k] = v.map((e) => '$e').toList();
            } else if (v is Map) {
              // {key: name} → values
              parsed[k] = v.values.map((e) => '$e').toList();
            }
          });
          if (parsed.isNotEmpty) {
            // 不能在 build 里 setState；用微任务
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_filterGroups != parsed) {
                setState(() => _filterGroups = parsed);
              }
            });
          }
        }
        final slivers = <Widget>[];

        if (list.isNotEmpty) {
          slivers.add(SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: HeroBannerCarousel(items: list),
            ),
          ));
        }

        // 继续观看（对标催壳历史条）
        slivers.add(const SliverToBoxAdapter(child: _ContinueWatchRow()));
        slivers.add(const SliverToBoxAdapter(child: _HotRankRow()));

        // 横向行（含上下键跨行焦点）
        final rowChildren = <Widget>[
          VodRow(title: '热门推荐', items: list),
          for (final cat in classes.take(6))
            _CategoryRow(
              typeId: cat.typeId,
              title: cat.typeName,
              fallback: list,
              onMore: () => setState(() => _selectedTypeId = cat.typeId),
            ),
        ];
        slivers.add(
          SliverToBoxAdapter(
            child: FocusableRowsColumn(rows: rowChildren),
          ),
        );

        if (list.isEmpty && classes.isEmpty) {
          slivers.add(
            const SliverToBoxAdapter(
              child: EmptyView(message: '暂无内容', icon: Icons.movie_filter_outlined),
            ),
          );
        }

        return slivers;
      },
    );
  }
}




class _HotRankRow extends ConsumerWidget {
  const _HotRankRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hotRankProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        // 编号角标感：改写 remarks 为 TOP n
        final ranked = <Vod>[
          for (var i = 0; i < list.length; i++)
            list[i].copyWith(remarks: 'TOP${i + 1}'),
        ];
        return VodRow(title: '热播榜', items: ranked);
      },
    );
  }
}

class _ContinueWatchRow extends ConsumerWidget {
  const _ContinueWatchRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(historyProvider);
    return histAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final vods = items.take(12).map((h) => h.vod).toList();
        return VodRow(
          title: '继续观看',
          items: vods,
          onMore: () => context.go('/history'),
        );
      },
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    required this.typeId,
    required this.title,
    required this.fallback,
    this.onMore,
  });

  final String typeId;
  final String title;
  final List<Vod> fallback;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryProvider((typeId: typeId, page: 1)));
    return async.when(
      loading: () => VodRow(title: title, items: fallback.take(8).toList()),
      error: (_, __) => VodRow(
        title: title,
        items: fallback.take(8).toList(),
        onMore: onMore,
      ),
      data: (list) => VodRow(
        title: title,
        items: list.isNotEmpty ? list : fallback.take(8).toList(),
        onMore: onMore,
      ),
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({required this.typeId, this.filterKey = ''});

  final String typeId;
  final String filterKey;

  String get _key => filterKey.isEmpty ? typeId : '$typeId::$filterKey';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoryPagerProvider(_key));
    final pager = ref.read(categoryPagerProvider(_key).notifier);

    if (state.loading && state.items.isEmpty) {
      return const PosterGridSkeleton();
    }
    if (state.error != null && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: ErrorView(message: state.error!, onRetry: pager.loadFirst),
      );
    }
    if (state.items.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyView(message: '该分类暂无内容', icon: Icons.folder_off_outlined),
      );
    }

    final count = state.items.length + 1;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= state.items.length) {
              if (state.hasMore && !state.loadingMore) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => pager.loadMore());
              }
              return Center(
                child: state.loadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const SizedBox.shrink(),
              );
            }
            if (index == state.items.length - 3) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => pager.loadMore());
            }
            return PosterCard(vod: state.items[index]);
          },
          childCount: count,
        ),
      ),
    );
  }
}

class _CategorySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, __) {
          return Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: Container(
              width: 64,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }
}
