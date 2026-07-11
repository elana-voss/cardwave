import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

enum AiActionEnum {
  proofread(icon: Icons.spellcheck),
  compact(icon: Icons.compress),
  translate(icon: Icons.translate),
  generatePreview(icon: Icons.auto_awesome, isGlobalOnly: true),
  autoTag(icon: Icons.local_offer, isGlobalOnly: true)
  ;

  final IconData icon;
  final bool isGlobalOnly;

  const AiActionEnum({required this.icon, this.isGlobalOnly = false});

  String get label => switch (this) {
    AiActionEnum.proofread => t.common.aiAction.proofread,
    AiActionEnum.compact => t.common.aiAction.compact,
    AiActionEnum.translate => t.common.aiAction.translate,
    AiActionEnum.generatePreview => t.common.aiAction.generatePreview,
    AiActionEnum.autoTag => t.common.aiAction.autoTag,
  };
}
