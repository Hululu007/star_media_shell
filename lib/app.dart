import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'services/spider/drpy/drpy_web_host_view.dart';

class StarMediaApp extends ConsumerWidget {
  const StarMediaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '星辰影音',
      debugShowCheckedModeBanner: false,
      themeMode: themeState.themeMode,
      theme: AppTheme.light(
        accent: themeState.accentColor,
        fontSizeFactor: themeState.fontSizeFactor,
        liquidGlass: themeState.liquidGlass,
      ),
      darkTheme: AppTheme.dark(
        accent: themeState.accentColor,
        fontSizeFactor: themeState.fontSizeFactor,
        liquidGlass: themeState.liquidGlass,
      ),
      routerConfig: router,
      builder: (context, child) {
        // 全局字号缩放 + 挂载隐藏 Drpy WebView 宿主
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(themeState.fontSizeFactor),
          ),
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const Offstage(child: DrpyWebHostView()),
            ],
          ),
        );
      },
    );
  }
}
