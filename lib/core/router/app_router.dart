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
                path: '/media',
                name: 'media',
                builder: (context, state) => const LivePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mine',
                name: 'mine',
                builder: (context, state) => const MinePage(),
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
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/source',
        name: 'source',
        builder: (context, state) => const SourcePage(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv_rounded),
            label: '直播',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: '搜索',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
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
