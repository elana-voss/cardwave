import 'dart:typed_data';

import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ImageCharacter extends StatefulWidget {
  const ImageCharacter({
    required this.imagePath,
    super.key,
    this.fit,
    this.cacheWidth,
    this.cacheHeight,
  });
  final String imagePath;
  final BoxFit? fit;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  State<ImageCharacter> createState() => _ImageCharacterState();
}

class _ImageCharacterState extends State<ImageCharacter> {
  late Future<Uint8List> _imageFuture;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  void _loadImage() {
    _imageFuture = context
        .read<AppStorage>()
        .readBytes(StorageDomainEnum.cards, widget.imagePath)
        .then(Uint8List.fromList);
  }

  @override
  void didUpdateWidget(covariant ImageCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return FutureBuilder<Uint8List>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            semanticLabel: t.common.characterImageSemanticLabel,
            fit: widget.fit,
            gaplessPlayback: true,
            cacheWidth: widget.cacheWidth,
            cacheHeight: widget.cacheHeight,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
