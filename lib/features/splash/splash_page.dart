import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/source_service.dart';
import '../../services/spider/spider_manager.dart';

/// 启动开屏（对标催壳启动页：Logo + 源检测）
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  String _status = '正在初始化…';

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _boot();
  }

  Future<void> _boot() async {
    try {
      setState(() => _status = '加载源配置…');
      final sources = await ref.read(sourcesProvider.future);
      if (sources.isNotEmpty) {
        final active = ref.read(activeSourceProvider);
        final ok = sources.any((s) => s.key == active.key);
        if (!ok) {
          ref.read(activeSourceProvider.notifier).state = sources.first;
        }
        setState(() => _status = '当前源：${ref.read(activeSourceProvider).name}');
      } else {
        setState(() => _status = '使用内置演示源');
      }
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _status = '准备就绪');
      await Future.delayed(const Duration(milliseconds: 350));
    } catch (_) {
      setState(() => _status = '启动完成');
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted) return;
    context.go('/');
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withOpacity(0.9),
              scheme.tertiary.withOpacity(0.75),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              FadeTransition(
                opacity: _anim,
                child: ScaleTransition(
                  scale: CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Icon(Icons.play_circle_fill_rounded,
                        size: 56, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '星辰影音',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '对标催壳的多运行时影视壳',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
