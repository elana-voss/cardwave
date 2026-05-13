import 'package:flutter/material.dart';

class WorkspaceSplitPane extends StatelessWidget {
  const WorkspaceSplitPane({
    required this.leftChild,
    required this.rightChild,
    super.key,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.showDivider = true,
  });
  final Widget leftChild;
  final Widget rightChild;
  final int leftFlex;
  final int rightFlex;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: leftFlex, child: leftChild),
        if (showDivider) const VerticalDivider(width: 1, thickness: 1),
        Expanded(flex: rightFlex, child: rightChild),
      ],
    );
  }
}
