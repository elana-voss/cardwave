import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';

/// A section-header band followed by [itemCount] rows built by
/// [buildItem], with hairline dividers between consecutive rows
/// (indented by [dividerIndent] so they clear the row's fixed-width
/// label column).
class MediaDenseSection extends StatelessWidget {
  const MediaDenseSection({
    required this.headerLabel,
    required this.itemCount,
    required this.buildItem,
    this.dividerIndent = 0,
    super.key,
  });
  final String headerLabel;
  final int itemCount;
  final Widget Function(int index) buildItem;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeaderBand(title: headerLabel),
        for (var i = 0; i < itemCount; i++) ...[
          buildItem(i),
          if (i < itemCount - 1)
            Divider(height: 1, thickness: 0.5, indent: dividerIndent),
        ],
      ],
    );
  }
}
