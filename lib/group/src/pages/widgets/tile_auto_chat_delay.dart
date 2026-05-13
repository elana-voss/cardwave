import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';

class TileAutoChatDelay extends StatelessWidget {
  const TileAutoChatDelay({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final Duration value;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final seconds = value.inSeconds;
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: const Text('Auto-chat delay'),
      subtitle: Slider(
        value: seconds.toDouble(),
        min: 1,
        max: 15,
        divisions: 14,
        label: '${seconds}s',
        onChanged: (v) => onChanged(Duration(seconds: v.round())),
      ),
      trailing: DrawerTrailingValue('${seconds}s'),
    );
  }
}
