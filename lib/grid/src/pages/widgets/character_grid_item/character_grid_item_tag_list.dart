import 'package:cardwave/character/character.dart';
import 'package:flutter/material.dart';

class CharacterGridItemTagList extends StatelessWidget {
  const CharacterGridItemTagList({required this.file, super.key});
  final CharacterFile file;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        file.card.tags.join(' • '),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
