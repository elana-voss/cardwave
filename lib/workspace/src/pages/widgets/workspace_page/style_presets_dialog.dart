import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:flutter/material.dart';

/// Image-style preset toggles. Backed by `characterFile.configMedia.imagePromptPrefix`
/// — the active toggles are derived from substring presence in the prefix
/// string, so legacy free-typed prefixes still surface their matching
/// preset chips. Toggling a chip flips the corresponding substring in the
/// prefix and persists the character via `saveJsonInCacheAndPngNow`.
/// Opened from the workspace end drawer's "Image Style" tile.
class StylePresetsDialog extends StatefulWidget {
  const StylePresetsDialog({
    required this.characterFile,
    required this.characterService,
    super.key,
  });
  final CharacterFile characterFile;
  final CharacterService characterService;

  @override
  State<StylePresetsDialog> createState() => _StylePresetsDialogState();
}

class _StylePresetsDialogState extends State<StylePresetsDialog> {
  static const List<String> _presets = [
    'anime',
    'photorealistic',
    'oil painting',
    'watercolor',
    'pixel art',
    'comic book',
    'pencil sketch',
    'digital art',
    '3D render',
    'fantasy illustration',
  ];

  late Set<String> _active;

  @override
  void initState() {
    super.initState();
    final current = widget.characterFile.configMedia?.imagePromptPrefix ?? '';
    _active = _presets
        .where((p) => current.toLowerCase().contains(p.toLowerCase()))
        .toSet();
  }

  void _toggle(String preset) {
    setState(() {
      if (_active.contains(preset)) {
        _active.remove(preset);
      } else {
        _active.add(preset);
      }
    });
    final combined = _active.isEmpty ? null : _active.join(', ');
    (widget.characterFile.configMedia ??= ConfigMediaCharacter())
            .imagePromptPrefix =
        combined;
    unawaited(
      widget.characterService.saveJsonInCacheAndPngNow(widget.characterFile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final combined = widget.characterFile.configMedia?.imagePromptPrefix ?? '';
    return AppDialog(
      builder: (ctx, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Image Style', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            combined.isEmpty ? 'No style selected' : combined,
            style: Theme.of(ctx).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                FilterChip(
                  label: Text(preset),
                  selected: _active.contains(preset),
                  onSelected: (_) => _toggle(preset),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
