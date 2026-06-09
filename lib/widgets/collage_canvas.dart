import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/collage_editor/models/collage_project.dart';
import '../features/collage_editor/state/collage_editor_state.dart';
import 'freeform_element_widget.dart';
import 'photo_filter_wrapper.dart';
import 'package:image_picker/image_picker.dart';

class CollageCanvas extends ConsumerStatefulWidget {
  final GlobalKey repaintBoundaryKey;
  final Size size;

  const CollageCanvas({
    super.key,
    required this.repaintBoundaryKey,
    required this.size,
  });

  @override
  ConsumerState<CollageCanvas> createState() => _CollageCanvasState();
}

class _CollageCanvasState extends ConsumerState<CollageCanvas> {
  // Gesture tracking variables for slot pan/zoom
  double _initialScale = 1.0;
  Offset _initialPan = Offset.zero;
  Offset _initialFocalPoint = Offset.zero;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImageForSlot(String slotId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        ref.read(collageEditorProvider.notifier).setSlotPhoto(slotId, image.path);
      }
    } catch (e) {
      debugPrint('Error picking image for slot: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(collageEditorProvider);
    final project = editorState.project;

    if (project == null) {
      return const SizedBox.shrink();
    }

    final double width = widget.size.width;
    final double height = widget.size.height;

    // Build the background decoration
    Widget backgroundWidget;
    switch (project.background.type) {
      case BackgroundType.gradient:
        backgroundWidget = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: (project.background.gradientColors ?? [0xFF121212, 0xFF121212])
                  .map((c) => Color(c))
                  .toList(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
        break;
      case BackgroundType.image:
        if (project.background.imagePath != null) {
          Widget imgWidget = kIsWeb
              ? Image.network(project.background.imagePath!, fit: BoxFit.cover)
              : Image.file(File(project.background.imagePath!), fit: BoxFit.cover);

          if (project.background.blurRadius > 0) {
            imgWidget = ImageFiltered(
              imageFilter: javaScriptBlurFilter(project.background.blurRadius),
              child: imgWidget,
            );
          }
          backgroundWidget = SizedBox(
            width: width,
            height: height,
            child: imgWidget,
          );
        } else {
          backgroundWidget = Container(
            width: width,
            height: height,
            color: Color(project.background.solidColor),
          );
        }
        break;
      case BackgroundType.blur:
        // Use a blurred placeholder color or background image representation
        backgroundWidget = Container(
          width: width,
          height: height,
          color: Color(project.background.solidColor).withValues(alpha: 0.8),
        );
        break;
      case BackgroundType.solid:
      default:
        backgroundWidget = Container(
          width: width,
          height: height,
          color: Color(project.background.solidColor),
        );
    }

    // Build grid slots
    List<Widget> slotWidgets = [];
    if (project.templateId != null) {
      for (final slot in project.slots) {
        final rect = slot.rect.toRect(widget.size);
        final isSelected = editorState.selectedSlotId == slot.id;

        // Slot content: Photo, default placeholder, or loading state
        Widget slotContent;
        if (slot.photo != null) {
          // Photo is present, render it with filters applied
          slotContent = PhotoFilterWrapper(
            element: slot.photo!,
            fitSize: Size(rect.width, rect.height),
          );
        } else {
          // No photo, show an elegant M3 tap-to-add placeholder
          slotContent = InkWell(
            onTap: () => _pickImageForSlot(slot.id),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      size: (rect.width * 0.25).clamp(24.0, 48.0),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to Add',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: (rect.width * 0.08).clamp(9.0, 12.0),
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Apply gridCornerRadius and gridSpacing (which acts as layout border padding)
        slotWidgets.add(
          Positioned.fromRect(
            rect: rect,
            child: GestureDetector(
              onTap: () {
                if (slot.photo != null) {
                  ref.read(collageEditorProvider.notifier).selectSlot(slot.id);
                } else {
                  _pickImageForSlot(slot.id);
                }
              },
              onScaleStart: (details) {
                if (slot.photo != null && !isSelected) {
                  ref.read(collageEditorProvider.notifier).selectSlot(slot.id);
                }
                _initialScale = slot.photo?.scale ?? 1.0;
                _initialPan = Offset(slot.photo?.panX ?? 0.0, slot.photo?.panY ?? 0.0);
                _initialFocalPoint = details.localFocalPoint;
              },
              onScaleUpdate: (details) {
                if (slot.photo == null) return;

                // Allow panning and zooming the photo inside the slot
                final double nextScale = (_initialScale * details.scale).clamp(1.0, 5.0);
                
                // Calculate absolute translation since gesture start
                final Offset translation = details.localFocalPoint - _initialFocalPoint;
                final double nextPanX = _initialPan.dx + translation.dx;
                final double nextPanY = _initialPan.dy + translation.dy;

                ref.read(collageEditorProvider.notifier).updateSlotPhotoTransform(
                      slot.id,
                      scale: nextScale,
                      panX: nextPanX,
                      panY: nextPanY,
                    );
              },
              onScaleEnd: (_) {
                ref.read(collageEditorProvider.notifier).commitTransform();
              },
              child: Container(
                padding: EdgeInsets.all(project.gridSpacing / 2),
                decoration: BoxDecoration(
                  color: Color(project.gridBorderColor),
                  borderRadius: BorderRadius.circular(project.gridCornerRadius),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    (project.gridCornerRadius - project.gridSpacing / 2).clamp(0.0, double.infinity),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: slotContent),
                      // If slot is selected, draw a highlight border
                      if (isSelected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // Build freeform elements (Images, text, stickers)
    List<Widget> elementWidgets = [];
    final sortedElements = List<CollageElement>.from(project.freeElements)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    for (final element in sortedElements) {
      final isSelected = editorState.selectedElementId == element.id;

      Widget elementContent;
      switch (element.type) {
        case 'photo':
          elementContent = PhotoFilterWrapper(
            element: element,
            fitSize: Size(element.width, element.height),
          );
          break;
        case 'text':
          // Render custom text with custom typography and shadow
          final shadow = element.hasShadow
              ? [
                  Shadow(
                    color: Color(element.shadowColor),
                    offset: const Offset(2.0, 2.0),
                    blurRadius: 4.0,
                  )
                ]
              : null;

          final alignment = element.alignment == 'left'
              ? TextAlign.left
              : (element.alignment == 'right' ? TextAlign.right : TextAlign.center);

          elementContent = Center(
            child: Text(
              element.text ?? 'Double Tap to Edit',
              textAlign: alignment,
              style: GoogleFonts.getFont(
                element.fontFamily,
                fontSize: element.fontSize,
                color: Color(element.textColor),
                fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
                fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
                shadows: shadow,
              ),
            ),
          );
          break;
        case 'sticker':
          if (element.stickerType == 'emoji') {
            elementContent = Center(
              child: Text(
                element.stickerValue ?? '✨',
                style: TextStyle(
                  fontSize: element.width * 0.7,
                ),
              ),
            );
          } else {
            // Decorative shapes fallback to clean built-in icons
            elementContent = Center(
              child: Icon(
                _getStickerIcon(element.stickerValue),
                size: element.width * 0.8,
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }
          break;
        default:
          elementContent = const SizedBox.shrink();
      }

      elementWidgets.add(
        FreeformElementWidget(
          element: element,
          isSelected: isSelected,
          onTap: () {
            ref.read(collageEditorProvider.notifier).selectElement(element.id);
          },
          onDrag: (dx, dy) {
            double newX = element.x + dx;
            double newY = element.y + dy;

            // Alignment Snapping logic: Snap to horizontal/vertical center guidelines
            if (editorState.isSnapToGuides) {
              final double canvasCenterX = width / 2;
              final double canvasCenterY = height / 2;
              final double elementCenterX = newX + element.width / 2;
              final double elementCenterY = newY + element.height / 2;

              // Snap X
              if ((elementCenterX - canvasCenterX).abs() < 12.0) {
                newX = canvasCenterX - element.width / 2;
              }
              // Snap Y
              if ((elementCenterY - canvasCenterY).abs() < 12.0) {
                newY = canvasCenterY - element.height / 2;
              }
            }

            ref.read(collageEditorProvider.notifier).updateElementTransform(
                  element.id,
                  x: newX,
                  y: newY,
                );
          },
          onResize: (w, h, dx, dy) {
            ref.read(collageEditorProvider.notifier).updateElementTransform(
                  element.id,
                  width: (w + dx).clamp(40.0, width),
                  height: (h + dy).clamp(40.0, height),
                );
          },
          onRotate: (angle) {
            ref.read(collageEditorProvider.notifier).updateElementTransform(
                  element.id,
                  angle: angle,
                );
          },
          onDelete: () {
            ref.read(collageEditorProvider.notifier).deleteElement(element.id);
          },
          onDuplicate: () {
            ref.read(collageEditorProvider.notifier).duplicateElement(element.id);
          },
          onDragEnd: () {
            ref.read(collageEditorProvider.notifier).commitTransform();
          },
          child: elementContent,
        ),
      );
    }

    // Snapping lines overlay helper
    Widget? snapLines;
    if (editorState.isSnapToGuides && editorState.selectedElementId != null) {
      final selectedElement = project.freeElements.firstWhere(
        (e) => e.id == editorState.selectedElementId,
        orElse: () => const CollageElement(id: '', type: ''),
      );

      if (selectedElement.id.isNotEmpty) {
        final double canvasCenterX = width / 2;
        final double canvasCenterY = height / 2;
        final double elementCenterX = selectedElement.x + selectedElement.width / 2;
        final double elementCenterY = selectedElement.y + selectedElement.height / 2;

        final bool showVert = (elementCenterX - canvasCenterX).abs() < 1.0;
        final bool showHoriz = (elementCenterY - canvasCenterY).abs() < 1.0;

        if (showVert || showHoriz) {
          snapLines = IgnorePointer(
            child: CustomPaint(
              size: Size(width, height),
              painter: GuideLinesPainter(
                showVertical: showVert,
                showHorizontal: showHoriz,
                centerX: canvasCenterX,
                centerY: canvasCenterY,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          );
        }
      }
    }

    // Grid Overlay helper
    Widget? gridOverlay;
    if (editorState.isGridOverlay) {
      gridOverlay = IgnorePointer(
        child: CustomPaint(
          size: Size(width, height),
          painter: GridOverlayPainter(
            gridColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return RepaintBoundary(
      key: widget.repaintBoundaryKey,
      child: GestureDetector(
        onTap: () {
          // Tap on blank canvas deselects everything
          ref.read(collageEditorProvider.notifier).selectElement(null);
          ref.read(collageEditorProvider.notifier).selectSlot(null);
        },
        child: Container(
          width: width,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black12,
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Background
              Positioned.fill(child: backgroundWidget),
              
              // 2. Template slots
              ...slotWidgets,
              
              // 3. Freeform elements
              ...elementWidgets,
              
              // 4. Snap Lines
              ?snapLines,

              // 5. Grid Overlay
              ?gridOverlay,
            ],
          ),
        ),
      ),
    );
  }

  // Helper to map shape strings to Flutter Icons
  IconData _getStickerIcon(String? value) {
    switch (value) {
      case 'star':
        return Icons.star;
      case 'heart':
        return Icons.favorite;
      case 'circle':
        return Icons.circle;
      case 'square':
        return Icons.crop_square;
      case 'triangle':
        return Icons.change_history;
      case 'sun':
        return Icons.wb_sunny;
      case 'moon':
        return Icons.dark_mode;
      case 'fire':
        return Icons.local_fire_department;
      default:
        return Icons.category;
    }
  }

  // Cross-platform safe blur filter
  ui.ImageFilter javaScriptBlurFilter(double radius) {
    return ui.ImageFilter.blur(sigmaX: radius, sigmaY: radius);
  }
}

// Custom painter for 3x3 rule-of-thirds grid overlay
class GridOverlayPainter extends CustomPainter {
  final Color gridColor;

  GridOverlayPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Vertical lines
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);

    // Horizontal lines
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for snapping guidelines
class GuideLinesPainter extends CustomPainter {
  final bool showVertical;
  final bool showHorizontal;
  final double centerX;
  final double centerY;
  final Color color;

  GuideLinesPainter({
    required this.showVertical,
    required this.showHorizontal,
    required this.centerX,
    required this.centerY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dashHeight = 5.0;
    final dashSpace = 3.0;

    if (showVertical) {
      // Draw dashed vertical center line
      double startY = 0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(centerX, startY),
          Offset(centerX, startY + dashHeight),
          paint,
        );
        startY += dashHeight + dashSpace;
      }
    }

    if (showHorizontal) {
      // Draw dashed horizontal center line
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, centerY),
          Offset(startX + dashHeight, centerY),
          paint,
        );
        startX += dashHeight + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant GuideLinesPainter oldDelegate) {
    return oldDelegate.showVertical != showVertical ||
        oldDelegate.showHorizontal != showHorizontal ||
        oldDelegate.color != color;
  }
}
