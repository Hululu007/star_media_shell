import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/widgets/glass_container.dart';
import '../../core/widgets/async_body.dart';
import '../../models/vod.dart';
import '../../services/paging.dart';
import '../../services/storage_service.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      ref.read(searchPagerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit(String text) async {
    final q = text.trim();
    if (q.isEmpty) return;
    await ref.read(storageServiceProvider).addSearchKeyword(q);
    ref.invalidate(searchHistoryProvider);
    await ref.read(searchPagerProvider.notifier).search(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchPagerProvider);
    final historyAsync = ref.watch(searchHistoryProvider);
    final hasQuery = state.loading ||
        state.items.isNotEmpty ||
        state.error != null ||
        state.page > 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索影视…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
          onSubmitted: _submit,
        ),
        actions: [
          TextButton(
            onPressed: () => _submit(_controller.text),
            child: const Text('搜索'),
          ),
        ],
      ),
      body: !hasQuery && state.error == null
          ? _buildHistory(historyAsync)
          : _buildResults(state),
    );
  }

  Widget _buildResults(PagedListState state) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorView(
        message: '搜索失败: ${state.error}',
        onRetry: () => _submit(_controller.text),
      );
    }
    if (state.items.isEmpty) {
      return const EmptyView(
        message: '没有找到相关内容',
        icon: Icons.search_off_rounded,
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: state.items.length + 1,
      itemBuilder: (context, i) {
        if (i == state.items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: state.loadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      state.hasMore ? '' : '没有更多了',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
          );
        }
        return _SearchTile(vod: state.items[i]);
      },
    );
  }

  Widget _buildHistory(AsyncValue<List<String>> historyAsync) {
    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (history) {
        if (history.isEmpty) {
          return EmptyView(
            message: '输入关键词开始搜索',
            icon: Icons.search_rounded,
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                Text('搜索历史', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await ref.read(storageServiceProvider).clearSearchHistory();
                    ref.invalidate(searchHistoryProvider);
                  },
                  child: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: history.map((k) {
                return ActionChip(
                  label: Text(k),
                  onPressed: () {
                    _controller.text = k;
                    _submit(k);
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _SearchTile extends StatelessWidget {
  const _SearchTile({required this.vod});

  final Vod vod;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Focus(
        child: GlassCard(
          padding: EdgeInsets.zero,
          onTap: () => context.push('/detail/${vod.id}'),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.movie_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(vod.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [vod.year, vod.type, vod.remarks]
                  .where((e) => e != null && e.isNotEmpty)
                  .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ),
    );
  }
}
