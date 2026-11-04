import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/widgets/glass_container.dart';
import '../../services/announcement_service.dart';
import '../../services/epg_service.dart';
import '../../services/rank_service.dart';
import '../../services/spider/python/python_host.dart';
import '../../services/icon_service.dart';
import '../../services/live_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ========== 外观 ==========
          _SectionTitle(title: '外观'),
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                // 主题模式
                ListTile(
                  leading: const Icon(Icons.brightness_6_rounded),
                  title: const Text('外观模式'),
                  subtitle: Text(_themeModeLabel(themeState.themeMode)),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode, size: 18),
                      ),
                    ],
                    selected: {themeState.themeMode},
                    onSelectionChanged: (s) => controller.setThemeMode(s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),

                // 强调色
                ListTile(
                  leading: const Icon(Icons.palette_rounded),
                  title: const Text('强调色'),
                  subtitle: const Text('点击选择喜欢的颜色'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppColors.accentPresets.map((color) {
                      final selected = themeState.accentColor.value == color.value;
                      return GestureDetector(
                        onTap: () => controller.setAccentColor(color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1, indent: 56),

                // 液态玻璃
                SwitchListTile(
                  secondary: const Icon(Icons.blur_on_rounded),
                  title: const Text('液态玻璃'),
                  subtitle: const Text('毛玻璃效果，更有现代感'),
                  value: themeState.liquidGlass,
                  onChanged: controller.setLiquidGlass,
                ),
                const Divider(height: 1, indent: 56),

                // 字号
                ListTile(
                  leading: const Icon(Icons.format_size_rounded),
                  title: const Text('字号'),
                  subtitle: Text('${(themeState.fontSizeFactor * 100).round()}%'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      const Text('小', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: themeState.fontSizeFactor,
                          min: 0.85,
                          max: 1.25,
                          divisions: 8,
                          label: '${(themeState.fontSizeFactor * 100).round()}%',
                          onChanged: controller.setFontSizeFactor,
                        ),
                      ),
                      const Text('大', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ========== 首页与导航 ==========
          _SectionTitle(title: '首页与导航'),
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.view_carousel_rounded),
                  title: const Text('首页轮播海报'),
                  subtitle: const Text('显示推荐轮播'),
                  value: true,
                  onChanged: (_) {},
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.tv_rounded),
                  title: const Text('电视模式'),
                  subtitle: const Text('优化遥控器操作与焦点'),
                  value: false,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),


          const SizedBox(height: 24),

          // ========== 桌面图标 ==========
          _SectionTitle(title: '桌面图标'),
          GlassContainer(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '切换后可能需等待几秒或重新进入桌面才能看到新图标（部分桌面需重启启动器）',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final currentAsync = ref.watch(currentIconProvider);
                    final current = currentAsync.valueOrNull ?? 'default_star';
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: kAppIcons.map((icon) {
                        final selected = current == icon.key;
                        return GestureDetector(
                          onTap: () async {
                            final ok = await ref.read(iconServiceProvider).setIcon(icon.key);
                            ref.invalidate(currentIconProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? '已切换为「${icon.name}」'
                                        : '切换失败（请确认已合并 AndroidManifest 图标配置）',
                                  ),
                                ),
                              );
                            }
                          },
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Color(icon.color),
                                  borderRadius: BorderRadius.circular(14),
                                  border: selected
                                      ? Border.all(color: Colors.white, width: 3)
                                      : null,
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: Color(icon.color).withOpacity(0.45),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                                child: selected
                                    ? const Icon(Icons.check, color: Colors.white, size: 22)
                                    : Icon(Icons.apps_rounded, color: Colors.white.withOpacity(0.9), size: 22),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                icon.name,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          
          const SizedBox(height: 24),
          _SectionTitle(title: '运行时'),

          FutureBuilder<bool>(
            future: PythonHost.instance.isAvailable(),
            builder: (context, snap) {
              final ok = snap.data == true;
              return GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: ok ? Colors.green : null,
                  ),
                  title: const Text('Python 运行时'),
                  subtitle: Text(
                    ok
                        ? 'Chaquopy 已就绪（真调用）'
                        : '未检测到 Chaquopy，使用 Dart Fallback',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          _SectionTitle(title: '订阅'),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('添加资源'),
              subtitle: const Text('TVBox 订阅 / 粘贴配置 / 本地导入'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/source/add'),
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('源订阅仓库'),
              subtitle: const Text('远程仓库同步影视源'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/source/repo'),
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('直播 m3u 地址'),
                  subtitle: const Text('订阅网络直播源'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final svc = ref.read(liveServiceProvider);
                    final cur = await svc.getSavedUrl() ?? '';
                    final c = TextEditingController(text: cur);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('m3u 地址'),
                        content: TextField(controller: c, maxLines: 2),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await svc.saveUrl(c.text.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已保存直播源')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('远程公告 URL'),
                  subtitle: const Text('JSON 公告，可选'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final svc = ref.read(announcementServiceProvider);
                    final cur = await svc.getRemoteUrl() ?? '';
                    final c = TextEditingController(text: cur);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('公告 JSON 地址'),
                        content: TextField(
                          controller: c,
                          decoration: const InputDecoration(
                            hintText: 'https://example.com/announce.json',
                          ),
                          maxLines: 2,
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await svc.setRemoteUrl(c.text.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已保存公告地址')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('EPG 地址'),
                  subtitle: const Text('JSON 或 XMLTV'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final svc = ref.read(epgServiceProvider);
                    final cur = await svc.getUrl() ?? '';
                    final c = TextEditingController(text: cur);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('EPG JSON'),
                        content: TextField(controller: c, maxLines: 2),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await svc.setUrl(c.text.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已保存 EPG 地址')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('榜单 JSON 地址'),
                  subtitle: const Text('首页热播榜远程数据'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final svc = ref.read(rankServiceProvider);
                    final cur = await svc.getRemoteUrl() ?? '';
                    final c = TextEditingController(text: cur);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('榜单 JSON'),
                        content: TextField(controller: c, maxLines: 2),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await svc.setRemoteUrl(c.text.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已保存榜单地址')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          // ========== 关于 ==========
          _SectionTitle(title: '关于'),
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('版本'),
                  trailing: Text('0.1.0 (骨架)'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('项目说明'),
                  subtitle: const Text('Flutter 多运行时影视壳 · 对标 BieCuiLe'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
