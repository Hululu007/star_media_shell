import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/vod.dart';
import 'poster_card.dart';

/// 催壳风格横向影片行（支持左右键焦点移动）
class VodRow extends StatefulWidget {
  const VodRow({
    super.key,
    required this.title,
    required this.items,
    this.onMore,
  });

  final String title;
  final List<Vod> items;
  final VoidCallback? onMore;

  @override
  State<VodRow> createState() => _VodRowState();
}

class _VodRowState extends State<VodRow> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _ensureVisible(int index) {
    if (!_scroll.hasClients) return;
    const itemWidth = 128.0; // 118 + separator
    final offset = (index * itemWidth).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      offset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (widget.onMore != null)
                TextButton(
                  onPressed: widget.onMore,
                  child: const Text('更多'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 210,
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                return SizedBox(
                  width: 118,
                  child: Focus(
                    onFocusChange: (has) {
                      if (has) _ensureVisible(i);
                    },
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) {
                        return KeyEventResult.ignored;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                          i < widget.items.length - 1) {
                        node.nextFocus();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                          i > 0) {
                        node.previousFocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Builder(
                      builder: (context) {
                        final focused = Focus.of(context).hasFocus;
                        return AnimatedScale(
                          scale: focused ? 1.06 : 1.0,
                          duration: const Duration(milliseconds: 120),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: focused
                                  ? Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                              boxShadow: focused
                                  ? [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.35),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: PosterCard(vod: widget.items[i]),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
