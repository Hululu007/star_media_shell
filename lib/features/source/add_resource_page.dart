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

/// 添加资源 — 原版分组卡片样式
class AddResourcePage extends ConsumerWidget {
  const AddResourcePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerHighest.withOpacity(0.35),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('添加资源',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Label('影视源'),
          _Card(
            children: [
              _RowItem(
                color: const Color(0xFF3B82F6),
                icon: Icons.layers_rounded,
                title: 'TVBox 影视源',
                subtitle: '填配置地址，聚合多个点播平台',
                onTap: () => _tvbox(context, ref),
              ),
              _RowItem(
                color: const Color(0xFF8B5CF6),
                icon: Icons.cloud_download_rounded,
                title: '源订阅仓库',
                subtitle: '管理远程仓库并一键同步',
                onTap: () => context.push('/source/repo'),
              ),
              _RowItem(
                color: const Color(0xFF06B6D4),
                icon: Icons.article_outlined,
                title: '粘贴站点 / 配置文本',
                subtitle: 'JSON、TVBox 配置、单站 api 文本',
                onTap: () => _paste(context, ref),
              ),
              _RowItem(
                color: const Color(0xFFF59E0B),
                icon: Icons.cell_tower_rounded,
                title: '直播频道',
                subtitle: 'M3U / TXT 直播列表地址',
                onTap: () => _liveUrl(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Label('从本地导入'),
          _Card(
            children: [
              _RowItem(
                color: const Color(0xFF3B82F6),
                icon: Icons.insert_drive_file_outlined,
                title: '导入文件',
                subtitle: 'json / txt / TVBox 配置，可多选',
                onTap: () => _pick(context, ref, liveOnly: false),
              ),
              _RowItem(
                color: const Color(0xFFF59E0B),
                icon: Icons.cell_tower_rounded,
                title: '导入直播列表文件',
                subtitle: '本地 M3U / TXT 直播源，可多选',
                onTap: () => _pick(context, ref, liveOnly: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _tvbox(BuildContext context, WidgetRef ref) async {
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
                decoration: const InputDecoration(labelText: '名称')),
            const SizedBox(height: 12),
            TextField(
              controller: urlC,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '配置地址',
                hintText: 'https://.../tvbox.json',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('订阅并同步')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final r = await ref
          .read(resourceImportServiceProvider)
          .subscribeTvBox(nameC.text, urlC.text);
      // 同步后给合并源写 siteCount
      ref.invalidate(sourcesProvider);
      ref.invalidate(sourceReposProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(r.message)));
        Navigator.maybePop(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('失败: $e')));
      }
    }
  }

  Future<void> _paste(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) c.text = data!.text!.trim();
    } catch (_) {}
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴配置'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: c,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText: '{"urls":[...]} 或站点数组 或 m3u',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('导入')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r =
        await ref.read(resourceImportServiceProvider).importConfigText(c.text);
    ref.invalidate(sourcesProvider);
    ref.invalidate(sourceReposProvider);
    ref.invalidate(liveChannelsAsyncProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.message)));
      if (r.sourcesAdded > 0 || r.liveChannels > 0) {
        Navigator.maybePop(context);
      }
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
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'M3U URL',
            hintText: 'https://.../live.m3u',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(liveServiceProvider).saveUrl(c.text.trim());
    ref.invalidate(liveChannelsAsyncProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存直播订阅')));
    }
  }

  Future<void> _pick(BuildContext context, WidgetRef ref,
      {required bool liveOnly}) async {
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
      ref.invalidate(liveChannelsAsyncProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(msgs.join('\n')),
              duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8, top: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 62,
                color: Theme.of(context).dividerColor.withOpacity(0.35),
              ),
          ],
        ],
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem({
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
