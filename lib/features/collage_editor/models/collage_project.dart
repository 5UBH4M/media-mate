import 'package:flutter/material.dart';

class NormalizedRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const NormalizedRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Rect toRect(Size canvasSize) {
    return Rect.fromLTWH(
      left * canvasSize.width,
      top * canvasSize.height,
      width * canvasSize.width,
      height * canvasSize.height,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    };
  }

  factory NormalizedRect.fromJson(Map<String, dynamic> json) {
    return NormalizedRect(
      left: (json['left'] as num).toDouble(),
      top: (json['top'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  NormalizedRect copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    return NormalizedRect(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

enum BackgroundType { solid, gradient, image, blur }

class CollageBackground {
  final BackgroundType type;
  final int solidColor; // ARGB value
  final List<int>? gradientColors; // ARGB values
  final List<double>? gradientStops;
  final double gradientAngle; // in degrees
  final String? imagePath; // Local path or asset url
  final double blurRadius; // for blur background type

  const CollageBackground({
    this.type = BackgroundType.solid,
    this.solidColor = 0xFF121212, // Default dark grey
    this.gradientColors,
    this.gradientStops,
    this.gradientAngle = 0.0,
    this.imagePath,
    this.blurRadius = 10.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'solidColor': solidColor,
      'gradientColors': gradientColors,
      'gradientStops': gradientStops,
      'gradientAngle': gradientAngle,
      'imagePath': imagePath,
      'blurRadius': blurRadius,
    };
  }

  factory CollageBackground.fromJson(Map<String, dynamic> json) {
    return CollageBackground(
      type: BackgroundType.values.firstWhere((e) => e.name == json['type'], orElse: () => BackgroundType.solid),
      solidColor: json['solidColor'] as int? ?? 0xFF121212,
      gradientColors: (json['gradientColors'] as List<dynamic>?)?.map((e) => e as int).toList(),
      gradientStops: (json['gradientStops'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
      gradientAngle: (json['gradientAngle'] as num?)?.toDouble() ?? 0.0,
      imagePath: json['imagePath'] as String?,
      blurRadius: (json['blurRadius'] as num?)?.toDouble() ?? 10.0,
    );
  }

  CollageBackground copyWith({
    BackgroundType? type,
    int? solidColor,
    List<int>? gradientColors,
    List<double>? gradientStops,
    double? gradientAngle,
    String? imagePath,
    double? blurRadius,
  }) {
    return CollageBackground(
      type: type ?? this.type,
      solidColor: solidColor ?? this.solidColor,
      gradientColors: gradientColors ?? this.gradientColors,
      gradientStops: gradientStops ?? this.gradientStops,
      gradientAngle: gradientAngle ?? this.gradientAngle,
      imagePath: imagePath ?? this.imagePath,
      blurRadius: blurRadius ?? this.blurRadius,
    );
  }
}

class CollageElement {
  final String id;
  final String type; // 'photo', 'text', 'sticker'
  
  // Positional and Transform Properties (relative to canvas, used for freeform)
  final double x;
  final double y;
  final double width;
  final double height;
  final double angle; // Rotation in radians
  final double opacity;
  final int zIndex;

  // Photo Specific Properties
  final String? imagePath;
  final double scale; // Zoom inside container/slot
  final double panX; // X pan inside container/slot
  final double panY; // Y pan inside container/slot
  final bool flipHorizontal;
  final bool flipVertical;
  
  // Non-destructive photo adjustments
  final double brightness; // -1.0 to 1.0 (default 0.0)
  final double contrast; // 0.0 to 2.0 (default 1.0)
  final double saturation; // 0.0 to 2.0 (default 1.0)
  final double exposure; // -1.0 to 1.0 (default 0.0)
  final double blur; // 0.0 to 20.0 (default 0.0)
  final double sharpen; // 0.0 to 5.0 (default 0.0)
  
  // Individual Border/Corner Properties
  final double borderWidth;
  final int borderColor;
  final double borderRadius;

  // Text Specific Properties
  final String? text;
  final String fontFamily;
  final double fontSize;
  final int textColor;
  final bool isBold;
  final bool isItalic;
  final bool hasShadow;
  final int shadowColor;
  final String alignment; // 'left', 'center', 'right'

  // Sticker Specific Properties
  final String? stickerType; // 'emoji', 'shape', 'decorative'
  final String? stickerValue; // emoji character, shape SVG name, or asset path

  const CollageElement({
    required this.id,
    required this.type,
    this.x = 100.0,
    this.y = 100.0,
    this.width = 150.0,
    this.height = 150.0,
    this.angle = 0.0,
    this.opacity = 1.0,
    this.zIndex = 0,
    
    // Photo defaults
    this.imagePath,
    this.scale = 1.0,
    this.panX = 0.0,
    this.panY = 0.0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.exposure = 0.0,
    this.blur = 0.0,
    this.sharpen = 0.0,
    this.borderWidth = 0.0,
    this.borderColor = 0xFFFFFFFF,
    this.borderRadius = 0.0,

    // Text defaults
    this.text,
    this.fontFamily = 'Inter',
    this.fontSize = 24.0,
    this.textColor = 0xFFFFFFFF,
    this.isBold = false,
    this.isItalic = false,
    this.hasShadow = false,
    this.shadowColor = 0x88000000,
    this.alignment = 'center',

    // Sticker defaults
    this.stickerType,
    this.stickerValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'angle': angle,
      'opacity': opacity,
      'zIndex': zIndex,
      'imagePath': imagePath,
      'scale': scale,
      'panX': panX,
      'panY': panY,
      'flipHorizontal': flipHorizontal,
      'flipVertical': flipVertical,
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'exposure': exposure,
      'blur': blur,
      'sharpen': sharpen,
      'borderWidth': borderWidth,
      'borderColor': borderColor,
      'borderRadius': borderRadius,
      'text': text,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'textColor': textColor,
      'isBold': isBold,
      'isItalic': isItalic,
      'hasShadow': hasShadow,
      'shadowColor': shadowColor,
      'alignment': alignment,
      'stickerType': stickerType,
      'stickerValue': stickerValue,
    };
  }

  factory CollageElement.fromJson(Map<String, dynamic> json) {
    return CollageElement(
      id: json['id'] as String,
      type: json['type'] as String,
      x: (json['x'] as num?)?.toDouble() ?? 100.0,
      y: (json['y'] as num?)?.toDouble() ?? 100.0,
      width: (json['width'] as num?)?.toDouble() ?? 150.0,
      height: (json['height'] as num?)?.toDouble() ?? 150.0,
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      zIndex: json['zIndex'] as int? ?? 0,
      imagePath: json['imagePath'] as String?,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      panX: (json['panX'] as num?)?.toDouble() ?? 0.0,
      panY: (json['panY'] as num?)?.toDouble() ?? 0.0,
      flipHorizontal: json['flipHorizontal'] as bool? ?? false,
      flipVertical: json['flipVertical'] as bool? ?? false,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1.0,
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0.0,
      blur: (json['blur'] as num?)?.toDouble() ?? 0.0,
      sharpen: (json['sharpen'] as num?)?.toDouble() ?? 0.0,
      borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 0.0,
      borderColor: json['borderColor'] as int? ?? 0xFFFFFFFF,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String?,
      fontFamily: json['fontFamily'] as String? ?? 'Inter',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
      textColor: json['textColor'] as int? ?? 0xFFFFFFFF,
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      hasShadow: json['hasShadow'] as bool? ?? false,
      shadowColor: json['shadowColor'] as int? ?? 0x88000000,
      alignment: json['alignment'] as String? ?? 'center',
      stickerType: json['stickerType'] as String?,
      stickerValue: json['stickerValue'] as String?,
    );
  }

  CollageElement copyWith({
    String? id,
    String? type,
    double? x,
    double? y,
    double? width,
    double? height,
    double? angle,
    double? opacity,
    int? zIndex,
    String? imagePath,
    double? scale,
    double? panX,
    double? panY,
    bool? flipHorizontal,
    bool? flipVertical,
    double? brightness,
    double? contrast,
    double? saturation,
    double? exposure,
    double? blur,
    double? sharpen,
    double? borderWidth,
    int? borderColor,
    double? borderRadius,
    String? text,
    String? fontFamily,
    double? fontSize,
    int? textColor,
    bool? isBold,
    bool? isItalic,
    bool? hasShadow,
    int? shadowColor,
    String? alignment,
    String? stickerType,
    String? stickerValue,
  }) {
    return CollageElement(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      angle: angle ?? this.angle,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      imagePath: imagePath ?? this.imagePath,
      scale: scale ?? this.scale,
      panX: panX ?? this.panX,
      panY: panY ?? this.panY,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      exposure: exposure ?? this.exposure,
      blur: blur ?? this.blur,
      sharpen: sharpen ?? this.sharpen,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      borderRadius: borderRadius ?? this.borderRadius,
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      hasShadow: hasShadow ?? this.hasShadow,
      shadowColor: shadowColor ?? this.shadowColor,
      alignment: alignment ?? this.alignment,
      stickerType: stickerType ?? this.stickerType,
      stickerValue: stickerValue ?? this.stickerValue,
    );
  }
}

class CollageSlot {
  final String id;
  final NormalizedRect rect;
  final CollageElement? photo; // The photo placed in this slot

  const CollageSlot({
    required this.id,
    required this.rect,
    this.photo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rect': rect.toJson(),
      'photo': photo?.toJson(),
    };
  }

  factory CollageSlot.fromJson(Map<String, dynamic> json) {
    return CollageSlot(
      id: json['id'] as String,
      rect: NormalizedRect.fromJson(json['rect'] as Map<String, dynamic>),
      photo: json['photo'] != null ? CollageElement.fromJson(json['photo'] as Map<String, dynamic>) : null,
    );
  }

  CollageSlot copyWith({
    String? id,
    NormalizedRect? rect,
    CollageElement? photo,
  }) {
    return CollageSlot(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      photo: photo ?? this.photo,
    );
  }
}

class CollageProject {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double aspectRatio; // Width / Height (e.g. 1.0, 16/9, 9/16, 4/3)
  final CollageBackground background;
  
  // Grid settings
  final String? templateId; // If using a template, otherwise null for Freeform
  final List<CollageSlot> slots;
  final double gridSpacing; // Padding between slots
  final double gridCornerRadius;
  final int gridBorderColor;

  // Floating Elements (Texts, Stickers, Free-form Photos)
  final List<CollageElement> freeElements;

  // Unused/Loaded photos pool to preserve images when switching templates
  final List<CollageElement> photoPool;

  final String? thumbnailPath; // Store preview draft thumbnail

  const CollageProject({
    required this.id,
    this.title = 'Untitled Collage',
    required this.createdAt,
    required this.updatedAt,
    this.aspectRatio = 1.0, // Square by default
    this.background = const CollageBackground(),
    this.templateId,
    this.slots = const [],
    this.gridSpacing = 8.0,
    this.gridCornerRadius = 12.0,
    this.gridBorderColor = 0xFF000000,
    this.freeElements = const [],
    this.photoPool = const [],
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'aspectRatio': aspectRatio,
      'background': background.toJson(),
      'templateId': templateId,
      'slots': slots.map((s) => s.toJson()).toList(),
      'gridSpacing': gridSpacing,
      'gridCornerRadius': gridCornerRadius,
      'gridBorderColor': gridBorderColor,
      'freeElements': freeElements.map((e) => e.toJson()).toList(),
      'photoPool': photoPool.map((e) => e.toJson()).toList(),
      'thumbnailPath': thumbnailPath,
    };
  }

  factory CollageProject.fromJson(Map<String, dynamic> json) {
    return CollageProject(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Collage',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 1.0,
      background: json['background'] != null
          ? CollageBackground.fromJson(json['background'] as Map<String, dynamic>)
          : const CollageBackground(),
      templateId: json['templateId'] as String?,
      slots: (json['slots'] as List<dynamic>?)?.map((s) => CollageSlot.fromJson(s as Map<String, dynamic>)).toList() ?? [],
      gridSpacing: (json['gridSpacing'] as num?)?.toDouble() ?? 8.0,
      gridCornerRadius: (json['gridCornerRadius'] as num?)?.toDouble() ?? 12.0,
      gridBorderColor: json['gridBorderColor'] as int? ?? 0xFF000000,
      freeElements: (json['freeElements'] as List<dynamic>?)
              ?.map((e) => CollageElement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      photoPool: (json['photoPool'] as List<dynamic>?)
              ?.map((e) => CollageElement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  CollageProject copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? aspectRatio,
    CollageBackground? background,
    String? templateId,
    List<CollageSlot>? slots,
    double? gridSpacing,
    double? gridCornerRadius,
    int? gridBorderColor,
    List<CollageElement>? freeElements,
    List<CollageElement>? photoPool,
    String? thumbnailPath,
  }) {
    return CollageProject(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      background: background ?? this.background,
      templateId: templateId ?? this.templateId,
      slots: slots ?? this.slots,
      gridSpacing: gridSpacing ?? this.gridSpacing,
      gridCornerRadius: gridCornerRadius ?? this.gridCornerRadius,
      gridBorderColor: gridBorderColor ?? this.gridBorderColor,
      freeElements: freeElements ?? this.freeElements,
      photoPool: photoPool ?? this.photoPool,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}
