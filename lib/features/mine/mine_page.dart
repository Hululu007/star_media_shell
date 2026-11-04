import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/theme/widgets/glass_container.dart';
import '../../services/source_service.dart';
import '../../services/storage_service.dart';

/// 我的（对标催壳：收藏/历史/源/设置聚合）
class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSourceProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GlassCard(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.movie_filter_rounded,
                    color: Theme.of(context).colorScheme.primary),
              ),
              title: const Text('星辰影音', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('当前源：${active.name}'),
              trailing: TextButton(
                onPressed: () => context.push('/source'),
                child: const Text('切换'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            children: [
              _Tile(
                icon: Icons.favorite_rounded,
                color: Colors.redAccent,
                title: '我的收藏',
                onTap: () => context.push('/mine/favorites'),
              ),
              _Tile(
                icon: Icons.history_rounded,
                color: Colors.orange,
                title: '观看历史',
                onTap: () => context.push('/mine/history'),
              ),
              _Tile(
                icon: Icons.dns_rounded,
                color: Colors.blue,
                title: '源管理',
                onTap: () => context.push('/source'),
              ),
              _Tile(
                icon: Icons.add_box_outlined,
                color: Colors.teal,
                title: '添加资源',
                onTap: () => context.push('/source/add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            children: [
              _Tile(
                icon: Icons.palette_outlined,
                color: Colors.purple,
                title: '外观主题',
                subtitle: switch (themeMode) {
                  ThemeMode.system => '跟随系统',
                  ThemeMode.light => '浅色',
                  ThemeMode.dark => '深色',
                },
                onTap: () {
                  final next = switch (themeMode) {
                    ThemeMode.system => ThemeMode.light,
                    ThemeMode.light => ThemeMode.dark,
                    ThemeMode.dark => ThemeMode.system,
                  };
                  ref.read(themeControllerProvider.notifier).setMode(next);
                },
              ),
              _Tile(
                icon: Icons.settings_rounded,
                color: Colors.blueGrey,
                title: '全部设置',
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
