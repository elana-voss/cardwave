import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class SwitchTileZdr extends StatelessWidget {
  const SwitchTileZdr({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: value,
        onChanged: onChanged,
        title: Text(t.common.zdrSwitch.title),
        subtitle: Text(
          t.common.zdrSwitch.subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }
}
