import 'package:flutter/material.dart';

enum AiActionEnum {
  proofread(label: 'Proofread', icon: Icons.spellcheck),
  compact(label: 'Compact Prose', icon: Icons.compress),
  translate(label: 'Translate to English', icon: Icons.translate),
  generatePreview(
    label: 'Generate Preview',
    icon: Icons.auto_awesome,
    isGlobalOnly: true,
  ),
  autoTag(label: 'Auto-Tag', icon: Icons.local_offer, isGlobalOnly: true)
  ;

  final String label;
  final IconData icon;
  final bool isGlobalOnly;

  const AiActionEnum({
    required this.label,
    required this.icon,
    this.isGlobalOnly = false,
  });
}
