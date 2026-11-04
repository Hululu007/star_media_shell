import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'drpy_web_host.dart';

/// 隐藏的 WebView，用于挂载 Drpy 宿主
/// 放在 MaterialApp 的 builder 里 Offstage 即可
class DrpyWebHostView extends StatefulWidget {
  const DrpyWebHostView({super.key});

  @override
  State<DrpyWebHostView> createState() => _DrpyWebHostViewState();
}

class _DrpyWebHostViewState extends State<DrpyWebHostView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    // 延后到首帧后 attach，避免部分机型过早初始化问题
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DrpyWebHost.instance.attach(_controller);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 极小尺寸，不占视觉
    return SizedBox(
      width: 1,
      height: 1,
      child: WebViewWidget(controller: _controller),
    );
  }
}
