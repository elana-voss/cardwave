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
        title: const Text('Require Zero Data Retention (ZDR)'),
        subtitle: const Text(
          'Only show OR models with ZDR-compliant endpoints. Enable this if '
          'your openrouter.ai account restricts to ZDR providers.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }
}
