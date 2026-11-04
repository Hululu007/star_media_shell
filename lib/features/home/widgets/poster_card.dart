import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/widgets/glass_container.dart';
import '../../../models/vod.dart';
import 'corner_badge.dart';

/// 通用海报卡片（首页 / 收藏等复用）
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.vod,
    this.onLongPress,
    this.trailing,
  });

  final Vod vod;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  static const _palette = [
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFF0984E3),
    Color(0xFFFD79A8),
    Color(0xFFFDCB6E),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[vod.id.hashCode.abs() % _palette.length];
    final hasPic = vod.pic != null && vod.pic!.startsWith('http');

    return GlassContainer(
      borderRadius: 12,
      padding: EdgeInsets.zero,
      onTap: () => context.push('/detail/${vod.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPic)
                    CachedNetworkImage(
                      imageUrl: vod.pic!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ShimmerBox(color: color),
                      errorWidget: (_, __, ___) => _GradientPlaceholder(color: color),
                      memCacheWidth: 400,
                    )
                  else
                    _GradientPlaceholder(color: color),
                  if (vod.remarks != null && vod.remarks!.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: CornerBadge(
                        text: vod.remarks!,
                        color: badgeColorFor(
                          vod.remarks,
                          Theme.of(context).colorScheme,
                        ),
                      ),
                    ),
                  if (trailing != null)
                    Positioned(right: 2, top: 2, child: trailing!),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vod.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  [vod.year, vod.type]
                      .where((e) => e != null && e.isNotEmpty)
                      .join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientPlaceholder extends StatelessWidget {
  const _GradientPlaceholder({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.75), color.withOpacity(0.35)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_rounded, size: 36, color: Colors.white70),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(color: color.withOpacity(0.3)),
    );
  }
}

/// 首页网格骨架
class PosterGridSkeleton extends StatelessWidget {
  const PosterGridSkeleton({super.key, this.count = 9});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, __) {
            return Shimmer.fromColors(
              baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          childCount: count,
        ),
      ),
    );
  }
}
