import 'package:flutter/material.dart';

/// 分类筛选条（对标催壳/TVBox 筛选）
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.groups,
    required this.selected,
    required this.onChanged,
  });

  /// 例如 { '类型': ['全部','动作','喜剧'], '年份': ['全部','2024','2023'] }
  final Map<String, List<String>> groups;
  final Map<String, String> selected;
  final void Function(String group, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((e) {
        return SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: e.value.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      e.key,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                );
              }
              final v = e.value[i - 1];
              final sel = (selected[e.key] ?? e.value.first) == v;
              return FilterChip(
                label: Text(v, style: const TextStyle(fontSize: 12)),
                selected: sel,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onChanged(e.key, v),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

/// 演示用默认筛选
Map<String, List<String>> demoFilters() => {
      '类型': ['全部', '动作', '喜剧', '爱情', '科幻', '悬疑'],
      '年份': ['全部', '2025', '2024', '2023', '2022'],
      '地区': ['全部', '大陆', '香港', '美国', '日本', '韩国'],
    };
