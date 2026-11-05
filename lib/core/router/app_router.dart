import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/detail/detail_page.dart';
import '../../features/splash/splash_page.dart';
import '../../features/favorite/favorite_page.dart';
import '../../features/history/history_page.dart';
import '../../features/live/live_page.dart';
import '../../features/home/home_page.dart';
import '../../features/player/player_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/mine/mine_page.dart';
import '../../features/source/source_page.dart';
import '../../features/source/source_repo_page.dart';
import '../../features/source/add_resource_page.dart';
import '../../models/vod.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorite',
                name: 'favorite',
                builder: (context, state) => const FavoritePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                name: 'history',
                builder: (context, state) => const HistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/source',
                name: 'source',
                builder: (context, state) => const SourcePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/mine/favorites',
        name: 'mine_favorites',
        builder: (context, state) => const FavoritePage(),
      ),
      GoRoute(
        path: '/mine/history',
        name: 'mine_history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/source/repo',
        name: 'source_repo',
        builder: (context, state) => const SourceRepoPage(),
      ),
      GoRoute(
        path: '/source/add',
        name: 'source_add',
        builder: (context, state) => const AddResourcePage(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: '/live',
        name: 'live',
        builder: (context, state) => const LivePage(),
      ),
      GoRoute(
        path: '/detail/:id',
        name: 'detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DetailPage(id: id);
        },
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final vod = extra?['vod'] as Vod?;
          final episode = extra?['episode'] as Episode?;
          final resume = extra?['resumePosition'] as int?;
          final playlist = extra?['playlist'] as List<Episode>?;
          final isLive = extra?['isLive'] as bool? ?? false;
          if (vod == null || episode == null) {
            return const Scaffold(body: Center(child: Text('参数错误')));
          }
          return PlayerPage(
            vod: vod,
            episode: episode,
            resumePosition: resume,
            playlist: playlist,
            isLive: isLive,
          );
        },
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _labels = ['媒体', '收藏', '历史', '资源', '设置'];
  static const _icons = [
    Icons.play_circle_outline_rounded,
    Icons.favorite_border_rounded,
    Icons.history_rounded,
    Icons.inventory_2_outlined,
    Icons.settings_outlined,
  ];
  static const _iconsSelected = [
    Icons.play_circle_rounded,
    Icons.favorite_rounded,
    Icons.history_rounded,
    Icons.inventory_2_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final idx = navigationShell.currentIndex;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Material(
                elevation: 3,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(28),
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: List.generate(5, (i) {
                      final sel = i == idx;
                      return Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => navigationShell.goBranch(
                            i,
                            initialLocation: i == idx,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: sel
                                  ? cs.primary.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  sel ? _iconsSelected[i] : _icons[i],
                                  size: 22,
                                  color: sel ? cs.primary : cs.onSurfaceVariant,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _labels[i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight:
                                        sel ? FontWeight.w700 : FontWeight.w500,
                                    color:
                                        sel ? cs.primary : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              elevation: 3,
              shadowColor: Colors.black26,
              shape: const CircleBorder(),
              color: cs.surface,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/search'),
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.search_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('功能开发中…', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
