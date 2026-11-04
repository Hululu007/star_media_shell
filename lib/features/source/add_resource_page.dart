import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/live_service.dart';
import '../../services/resource_import_service.dart';
import '../../services/source_repo_service.dart';
import '../../services/source_service.dart';

/// 添加资源（对标完整资源中心入口）
class AddResourcePage extends ConsumerWidget {
  const AddResourcePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加资源'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionLabel('影视源'),
          _GroupCard(
            children: [
              _Item(
                color: const Color(0xFF3B82F6),
                icon: Icons.layers_rounded,
                title: 'TVBox 影视源',
                subtitle: '填配置地址，聚合多个点播平台',
                onTap: () => _tvboxSubscribe(context, ref),
              ),
              _Item(
                color: const Color(0xFF8B5CF6),
                icon: Icons.cloud_download_rounded,
                title: '源订阅仓库',
                subtitle: '管理多个远程仓库并一键同步',
                onTap: () => context.push('/source/repo'),
              ),
              _Item(
                color: const Color(0xFF06B6D4),
                icon: Icons.paste_rounded,
                title: '粘贴站点 / 配置文本',
                subtitle: 'JSON、TVBox 配置、单站 api 文本',
                onTap: () => _pasteConfig(context, ref),
              ),
              _Item(
                color: const Color(0xFFF59E0B),
                icon: Icons.cell_tower_rounded,
                title: '直播频道',
                subtitle: 'M3U / TXT 直播列表地址',
                onTap: () => _liveUrl(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel('从本地导入'),
          _GroupCard(
            children: [
              _Item(
                color: const Color(0xFF3B82F6),
                icon: Icons.insert_drive_file_rounded,
                title: '导入文件',
                subtitle: 'json / txt / TVBox 配置，可选',
                onTap: () => _pickFiles(context, ref, liveOnly: false),
              ),
              _Item(
                color: const Color(0xFFF59E0B),
                icon: Icons.cell_tower_rounded,
                title: '导入直播列表文件',
                subtitle: '本地 M3U / TXT 直播源',
                onTap: () => _pickFiles(context, ref, liveOnly: true),
              ),
            ],
          ),
                  ],
      ),
    );
  }


  Future<void> _tvboxSubscribe(BuildContext context, WidgetRef ref) async {
    final nameC = TextEditingController(text: 'TVBox 订阅');
    final urlC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TVBox 影视源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlC,
              decoration: const InputDecoration(
                labelText: '配置地址',
                hintText: 'https://.../tvbox.json',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('订阅并同步')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await ref
        .read(resourceImportServiceProvider)
        .subscribeTvBox(nameC.text, urlC.text);
    ref.invalidate(sourcesProvider);
    ref.invalidate(sourceReposProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    }
  }

  Future<void> _pasteConfig(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    // 尝试剪贴板
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.trim().isNotEmpty) {
        c.text = data.text!.trim();
      }
    } catch (_) {}
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴配置'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: c,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: '{"urls":[...]} 或站点数组 或 m3u 文本',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('导入')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await ref.read(resourceImportServiceProvider).importConfigText(c.text);
    ref.invalidate(sourcesProvider);
    ref.invalidate(sourceReposProvider);
    ref.invalidate(liveChannelsAsyncProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    }
  }

  Future<void> _liveUrl(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final cur = await ref.read(liveServiceProvider).getSavedUrl();
    if (cur != null) c.text = cur;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('直播列表地址'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            labelText: 'M3U URL',
            hintText: 'https://.../live.m3u',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(liveServiceProvider).saveUrl(c.text.trim());
    ref.invalidate(liveChannelsAsyncProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存直播订阅地址')),
      );
    }
  }

  Future<void> _pickFiles(
    BuildContext context,
    WidgetRef ref, {
    required bool liveOnly,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: liveOnly
            ? const ['m3u', 'm3u8', 'txt']
            : const ['json', 'txt', 'm3u', 'm3u8', 'conf'],
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      final import = ref.read(resourceImportServiceProvider);
      final msgs = <String>[];
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) {
          msgs.add('${f.name}: 无法读取');
          continue;
        }
        final body = utf8.decode(bytes, allowMalformed: true);
        if (liveOnly) {
          await ref.read(liveServiceProvider).saveLocalBody(body);
          final n = ref.read(liveServiceProvider).parseM3u(body).length;
          msgs.add('${f.name}: $n 频道');
        } else {
          final r = await import.importLocalText(f.name, body);
          msgs.add('${f.name}: ${r.message}');
        }
      }
      ref.invalidate(sourcesProvider);
      ref.invalidate(sourceReposProvider);
      ref.invalidate(liveChannelsAsyncProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msgs.join('\n')), duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, indent: 64, color: Theme.of(context).dividerColor.withOpacity(0.4)),
          ],
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
