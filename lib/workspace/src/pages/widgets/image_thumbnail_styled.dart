import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';

class ImageThumbnailStyled extends StatelessWidget {
  const ImageThumbnailStyled({
    required this.file,
    super.key,
    this.onTapEdit,
    this.onTapClose,
    this.fullscreenOnTap = true,
    this.isVisible = true,
  });
  static const double _editIconRadius = 16;
  static const double _editIconSize = 16;

  final CharacterFile file;
  final VoidCallback? onTapEdit;
  final VoidCallback? onTapClose;
  final bool fullscreenOnTap;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final Widget thumbnail = ImageThumbnail(
      file: file,
      width: AppConstants.editorDesktopImageWidth,
    );

    final thumbnailTapable = GestureDetector(
      onTap: () => fullscreenOnTap
          ? ImageFullScreenViewer.show(
              context,
              file.card.cardwaveData.customAvatar ?? file.appCardImagePath,
            )
          : null,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: SizedBox(width: double.infinity, child: thumbnail),
      ),
    );

    return Container(
      width: AppConstants.editorDesktopImageWidth,
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            thumbnailTapable,
            // ImageThumbnail(
            //   file: file,
            //   width: AppConstants.editorDesktopImageWidth,
            // ),
            if (onTapClose != null)
              Positioned(
                left: 8,
                top: 8,
                child: InkWell(
                  onTap: onTapClose,
                  child: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: _editIconRadius,
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: _editIconSize,
                    ),
                  ),
                ),
              ),
            if (onTapEdit != null)
              Positioned(
                right: 8,
                top: 8,
                child: InkWell(
                  onTap: onTapEdit,
                  child: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: _editIconRadius,
                    child: Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: _editIconSize,
                    ),
                  ),
                ),
              ),
          ],
          // ),
        ),
      ),
    );
  }
}
