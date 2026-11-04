import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vod.dart';
import 'spider/spider_manager.dart';

class PagedListState {
  const PagedListState({
    this.items = const [],
    this.page = 0,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<Vod> items;
  final int page;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  PagedListState copyWith({
    List<Vod>? items,
    int? page,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return PagedListState(
      items: items ?? this.items,
      page: page ?? this.page,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CategoryPager extends StateNotifier<PagedListState> {
  CategoryPager(this.ref, this.typeId, {this.filter}) : super(const PagedListState()) {
    loadFirst();
  }

  final Ref ref;
  final String typeId;
  /// 筛选序列化字符串，传给 spider.category(filter: ...)
  final String? filter;

  Future<void> loadFirst() async {
    state = state.copyWith(loading: true, clearError: true, page: 0, hasMore: true);
    try {
      final source = ref.read(activeSourceProvider);
      final spider = await ref.read(spiderManagerProvider).getSpider(source);
      final list = await spider.category(typeId: typeId, page: 1, filter: filter);
      state = PagedListState(
        items: list,
        page: 1,
        loading: false,
        hasMore: list.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.loading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final next = state.page + 1;
      final source = ref.read(activeSourceProvider);
      final spider = await ref.read(spiderManagerProvider).getSpider(source);
      final list = await spider.category(typeId: typeId, page: next, filter: filter);
      state = state.copyWith(
        items: [...state.items, ...list],
        page: next,
        loadingMore: false,
        hasMore: list.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e.toString());
    }
  }
}

/// family 参数：`typeId` 或 `typeId::filterJson`
final categoryPagerProvider = StateNotifierProvider.autoDispose
    .family<CategoryPager, PagedListState, String>((ref, key) {
  final parts = key.split('::');
  final typeId = parts.first;
  final filter = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  return CategoryPager(ref, typeId, filter: filter);
});


class SearchPager extends StateNotifier<PagedListState> {
  SearchPager(this.ref) : super(const PagedListState());

  final Ref ref;
  String _keyword = '';

  String get keyword => _keyword;

  Future<void> search(String keyword) async {
    _keyword = keyword.trim();
    if (_keyword.isEmpty) {
      state = const PagedListState();
      return;
    }
    state = state.copyWith(loading: true, clearError: true, page: 0, hasMore: true, items: []);
    try {
      final source = ref.read(activeSourceProvider);
      final spider = await ref.read(spiderManagerProvider).getSpider(source);
      final list = await spider.search(_keyword, page: 1);
      state = PagedListState(
        items: list,
        page: 1,
        loading: false,
        hasMore: list.length >= 6,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (_keyword.isEmpty || state.loadingMore || !state.hasMore || state.loading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final next = state.page + 1;
      final source = ref.read(activeSourceProvider);
      final spider = await ref.read(spiderManagerProvider).getSpider(source);
      final list = await spider.search(_keyword, page: next);
      state = state.copyWith(
        items: [...state.items, ...list],
        page: next,
        loadingMore: false,
        hasMore: list.length >= 6,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e.toString());
    }
  }

  void clear() {
    _keyword = '';
    state = const PagedListState();
  }
}

final searchPagerProvider =
    StateNotifierProvider.autoDispose<SearchPager, PagedListState>((ref) {
  return SearchPager(ref);
});
