import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/models/group_activation_strategy_enum.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class TileActivationStrategy extends StatelessWidget {
  const TileActivationStrategy({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final GroupActivationStrategyEnum value;
  final ValueChanged<GroupActivationStrategyEnum> onChanged;

  Map<GroupActivationStrategyEnum, String> get _labels => {
    GroupActivationStrategyEnum.natural: t.group.tileActivationStrategy.naturalOption,
    GroupActivationStrategyEnum.list: t.group.tileActivationStrategy.roundRobinOption,
    GroupActivationStrategyEnum.random: t.group.tileActivationStrategy.randomOption,
  };

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return ListTile(
      leading: const Icon(Icons.record_voice_over_outlined),
      title: Text(t.group.tileActivationStrategy.title),
      trailing: DrawerTrailingValue(
        _labels[value]!,
        suffix: PopupMenuButton<GroupActivationStrategyEnum>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.swap_vert, size: 18),
          tooltip: t.group.tileActivationStrategy.changeSelectionTooltip,
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
