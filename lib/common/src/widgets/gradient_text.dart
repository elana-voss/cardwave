import 'package:cardwave/common/src/theme/compact_theme.dart';
import 'package:flutter/material.dart';

/// Paints [text] with a gradient fill via a shader mask. Defaults to the
/// CARDWAVE wordmark gradient; pass [gradient] to override. Drop it on any
/// header or logo to get the neon brand fill.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient = kCardwaveWordmarkGradient,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      // srcIn keeps only the glyph coverage and fills it with the shader,
      // so the child's own colour is irrelevant — white is a neutral base.
      child: Text(
        text,
        textAlign: textAlign,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}
