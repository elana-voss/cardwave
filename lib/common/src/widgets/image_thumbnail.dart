import 'dart:async';
import 'dart:typed_data';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/src/utils/utils_image.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ImageThumbnail extends StatefulWidget {
  const ImageThumbnail({
    required this.file,
    required this.width,
    super.key,
    this.height,
  });
  final CharacterFile file;
  final double width;
  final double? height;

  @override
  State<ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends State<ImageThumbnail> {
  StreamSubscription<CharacterFile>? _subscription;
  late Future<Uint8List?> _thumbnailFuture;
  late final CharacterService _characterService;
  String? _lastCustomAvatar;

  @override
  void initState() {
    super.initState();
    _characterService = context.read<CharacterService>();
    _lastCustomAvatar = widget.file.card.cardwaveData.customAvatar;
    _thumbnailFuture = _loadThumbnail();
    _subscribeToUpdates();
    _characterService.addListener(_onCharacterServiceChanged);
    unawaited(context.read<CharacterRepository>().ensureThumbnail(widget.file));
  }

  @override
  void didUpdateWidget(covariant ImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file.appCardThumbnailPath !=
            oldWidget.file.appCardThumbnailPath ||
        widget.file.card.cardwaveData.customAvatar !=
            oldWidget.file.card.cardwaveData.customAvatar) {
      unawaited(_subscription?.cancel());
      _thumbnailFuture = _loadThumbnail();
      _subscribeToUpdates();
      unawaited(
        context.read<CharacterRepository>().ensureThumbnail(widget.file),
      );
    }
  }

  void _subscribeToUpdates() {
    _subscription = context
        .read<CharacterRepository>()
        .onThumbnailGenerated
        .listen((file) {
          if (file.appCardThumbnailPath == widget.file.appCardThumbnailPath &&
              mounted) {
            setState(() {
              _thumbnailFuture = _loadThumbnail();
            });
          }
        });
  }

  Future<Uint8List?> _loadThumbnail() async {
    final appStorage = context.read<AppStorage>();

    // Prefer user-chosen custom avatar over the card PNG thumbnail.
    final customAvatar = widget.file.card.cardwaveData.customAvatar;
    if (customAvatar != null && customAvatar.isNotEmpty) {
      // Prefer the thumbnail sidecar; fall back to the original.
      final thumbPath = UtilsImage.thumbnailPathFor(customAvatar);
      final pathToLoad =
          await appStorage.fileExists(StorageDomainEnum.cards, thumbPath)
          ? thumbPath
          : customAvatar;
      if (await appStorage.fileExists(StorageDomainEnum.cards, pathToLoad)) {
        final bytes = await appStorage.readBytes(
          StorageDomainEnum.cards,
          pathToLoad,
        );
        return Uint8List.fromList(bytes);
      }
    }

    final exists = await appStorage.fileExists(
      StorageDomainEnum.cards,
      widget.file.appCardThumbnailPath,
    );
    if (exists) {
      final bytes = await appStorage.readBytes(
        StorageDomainEnum.cards,
        widget.file.appCardThumbnailPath,
      );
      return Uint8List.fromList(bytes);
    }
    return null;
  }

  void _onCharacterServiceChanged() {
    if (!mounted) return;
    final current = widget.file.card.cardwaveData.customAvatar;
    if (current != _lastCustomAvatar) {
      _lastCustomAvatar = current;
      setState(() {
        _thumbnailFuture = _loadThumbnail();
      });
    }
  }

  @override
  void dispose() {
    _characterService.removeListener(_onCharacterServiceChanged);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: Image.memory(
              snapshot.data!,
              semanticLabel: 'Character image',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
        }
        // While waiting for the future or if it returns false, show placeholder.
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: Icon(Icons.change_circle, size: 40, color: Colors.grey),
          ),
        );
      },
    );
  }
}
