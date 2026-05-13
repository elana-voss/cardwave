import 'dart:ui';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/src/widgets/image_thumbnail.dart';
import 'package:flutter/widgets.dart';

class ImageBackgroundBlurred extends StatelessWidget {
  const ImageBackgroundBlurred({required this.character, super.key});
  final CharacterFile character;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: ImageThumbnail(
          file: character,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
