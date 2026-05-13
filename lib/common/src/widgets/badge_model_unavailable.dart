import 'package:flutter/material.dart';

class BadgeModelUnavailable extends StatelessWidget {
  const BadgeModelUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message:
          'This model is no longer available from the provider — '
          'pick another.',
      child: Icon(
        Icons.warning_amber_rounded,
        color: Colors.orange,
        size: 16,
      ),
    );
  }
}
