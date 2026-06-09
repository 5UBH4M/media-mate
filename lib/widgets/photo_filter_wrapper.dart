import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../features/collage_editor/models/collage_project.dart';

class PhotoFilterWrapper extends StatelessWidget {
  final CollageElement element;
  final Widget? child;
  final Size? fitSize;

  const PhotoFilterWrapper({
    super.key,
    required this.element,
    this.child,
    this.fitSize,
  });

  @override
  Widget build(BuildContext context) {
    if (element.imagePath == null) {
      return const SizedBox.shrink();
    }

    // Load image widget based on path
    Widget imageWidget;
    if (kIsWeb) {
      // On web, imagePath might be a blob url or a remote url
      imageWidget = Image.network(
        element.imagePath!,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        width: fitSize?.width,
        height: fitSize?.height,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
        },
      );
    } else {
      // Local file on native platforms
      imageWidget = Image.file(
        File(element.imagePath!),
        fit: BoxFit.contain,
        alignment: Alignment.center,
        width: fitSize?.width,
        height: fitSize?.height,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
        },
      );
    }

    // Apply translation (pan) and scaling/zoom
    Widget transformedImage = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(element.panX, element.panY)
        ..scale(element.scale),
      child: imageWidget,
    );

    // Apply Flip (Horizontal & Vertical)
    if (element.flipHorizontal || element.flipVertical) {
      transformedImage = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(
            element.flipHorizontal ? -1.0 : 1.0,
            element.flipVertical ? -1.0 : 1.0,
          ),
        child: transformedImage,
      );
    }

    // Apply Blur (Gaussian)
    if (element.blur > 0) {
      transformedImage = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: element.blur, sigmaY: element.blur),
        child: transformedImage,
      );
    }

    // Apply Color Matrix Adjustments (Brightness, Contrast, Saturation, Exposure)
    final matrix = _getColorMatrix(
      brightness: element.brightness,
      contrast: element.contrast,
      saturation: element.saturation,
      exposure: element.exposure,
    );

    Widget filteredImage = ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: transformedImage,
    );

    // Apply Corners (Border Radius) & Borders
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(element.borderRadius),
        border: element.borderWidth > 0
            ? Border.all(
                color: Color(element.borderColor),
                width: element.borderWidth,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(element.borderRadius - (element.borderWidth / 2).clamp(0, double.infinity)),
        child: filteredImage,
      ),
    );
  }

  // Generate combined color matrix
  List<double> _getColorMatrix({
    required double brightness,
    required double contrast,
    required double saturation,
    required double exposure,
  }) {
    // 1. Exposure (scales all color channels)
    // Exposure scale factor: e.g. 1.0 + exposure (where exposure is -1 to 1)
    final double exp = exposure >= 0 ? (1.0 + exposure * 1.5) : (1.0 + exposure);

    // 2. Brightness offset (adds value to color channels)
    // brightness is -1 to 1, maps to -255 to 255 offset
    final double brightOffset = brightness * 100;

    // 3. Contrast scale and offset
    // contrast is 0 to 2, default is 1
    final double c = contrast;
    final double cOffset = 128 * (1.0 - c);

    // 4. Saturation matrix calculations
    // saturation is 0 to 2, default is 1
    final double s = saturation;
    const double lr = 0.2126;
    const double lg = 0.7152;
    const double lb = 0.0722;

    final double sr = (1.0 - s) * lr;
    final double sg = (1.0 - s) * lg;
    final double sb = (1.0 - s) * lb;

    // Combine steps into a single color matrix:
    // Red   = (R * exp * c) + (sr*R + sg*G + sb*B) + brightOffset + cOffset
    // Green = (G * exp * c) + (sr*R + sg*G + sb*B) + brightOffset + cOffset
    // Blue  = (B * exp * c) + (sr*R + sg*G + sb*B) + brightOffset + cOffset

    // To construct the 5x4 matrix:
    // [ a, b, c, d, e,
    //   f, g, h, i, j,
    //   k, l, m, n, o,
    //   p, q, r, s, t ]
    //
    // Applying sat + contrast + exposure + brightness:
    final double rScale = exp * c;
    final double offset = brightOffset + cOffset;

    return [
      rScale * (sr + s), rScale * sg,       rScale * sb,       0.0, offset,
      rScale * sr,       rScale * (sg + s), rScale * sb,       0.0, offset,
      rScale * sr,       rScale * sg,       rScale * (sb + s), 0.0, offset,
      0.0,               0.0,               0.0,               1.0, 0.0,
    ];
  }
}
