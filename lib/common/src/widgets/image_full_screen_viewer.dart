import 'dart:async';

import 'package:cardwave/common/src/widgets/image_character.dart';
import 'package:flutter/material.dart';

/// Fullscreen image zoom overlay.
///
/// Rendered as a `Dialog.fullscreen` rather than a pushed route so the chat
/// page beneath stays mounted — closing is an overlay dismiss instead of a
/// route pop, which avoids the `MaterialPageRoute` transition animation and
/// the first-frame repaint cost when the chat reveals.
class ImageFullScreenViewer extends StatelessWidget {
  const ImageFullScreenViewer({required this.imagePath, super.key});
  final String imagePath;

  // Public entry point — `Viewer.show(ctx, path)` is the call-site convention.
  // ignore: qcheck/prefer_widget_private_members
  static void show(BuildContext context, String imagePath) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: Colors.black,
        builder: (context) => ImageFullScreenViewer(imagePath: imagePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.1,
              maxScale: 5,
              child: ImageCharacter(imagePath: imagePath, fit: BoxFit.contain),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
