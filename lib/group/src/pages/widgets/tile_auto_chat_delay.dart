import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
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
    final t = Translations.of(context);
    final seconds = value.inSeconds;
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text(t.group.tileAutoChatDelay.title),
      subtitle: Slider(
        value: seconds.toDouble(),
        min: 1,
        max: 15,
        divisions: 14,
        label: t.group.tileAutoChatDelay.secondsAbbrev(seconds: seconds),
        onChanged: (v) => onChanged(Duration(seconds: v.round())),
      ),
      trailing: DrawerTrailingValue(
        t.group.tileAutoChatDelay.secondsAbbrev(seconds: seconds),
      ),
    );
  }
}
