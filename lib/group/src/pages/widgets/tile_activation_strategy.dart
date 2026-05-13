import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/models/group_activation_strategy_enum.dart';
import 'package:flutter/material.dart';

class TileActivationStrategy extends StatelessWidget {
  const TileActivationStrategy({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final GroupActivationStrategyEnum value;
  final ValueChanged<GroupActivationStrategyEnum> onChanged;

  static const _labels = {
    GroupActivationStrategyEnum.natural: 'Natural',
    GroupActivationStrategyEnum.list: 'Round-robin',
    GroupActivationStrategyEnum.random: 'Random',
  };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.record_voice_over_outlined),
      title: const Text('Speaker selection'),
      trailing: DrawerTrailingValue(
        _labels[value]!,
        suffix: PopupMenuButton<GroupActivationStrategyEnum>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.swap_vert, size: 18),
          tooltip: 'Change speaker selection',
          onSelected: onChanged,
          itemBuilder: (_) => [
            for (final entry in _labels.entries)
              PopupMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  style: entry.key == value
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
