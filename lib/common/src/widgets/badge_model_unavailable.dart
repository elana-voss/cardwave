import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class BadgeModelUnavailable extends StatelessWidget {
  const BadgeModelUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Tooltip(
      message: t.common.modelUnavailableTooltip,
      child: const Icon(
        Icons.warning_amber_rounded,
        color: Colors.orange,
        size: 16,
      ),
    );
  }
}
