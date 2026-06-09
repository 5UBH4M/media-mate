import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../services/project_service.dart';
import '../../templates/models/collage_template.dart';
import '../models/collage_project.dart';

class CollageEditorState {
  final CollageProject? project;
  final String? selectedElementId;
  final String? selectedSlotId;
  final double canvasZoom;
  final Offset canvasPan;
  final bool isGridOverlay;
  final bool isSnapToGuides;
  final List<CollageProject> undoStack;
  final List<CollageProject> redoStack;
  final bool isLoading;

  CollageEditorState({
    this.project,
    this.selectedElementId,
    this.selectedSlotId,
    this.canvasZoom = 1.0,
    this.canvasPan = Offset.zero,
    this.isGridOverlay = false,
    this.isSnapToGuides = true,
    this.undoStack = const [],
    this.redoStack = const [],
    this.isLoading = false,
  });

  CollageEditorState copyWith({
    CollageProject? project,
    String? selectedElementId,
    String? selectedSlotId,
    double? canvasZoom,
    Offset? canvasPan,
    bool? isGridOverlay,
    bool? isSnapToGuides,
    List<CollageProject>? undoStack,
    List<CollageProject>? redoStack,
    bool? isLoading,
  }) {
    return CollageEditorState(
      project: project ?? this.project,
      selectedElementId: selectedElementId == '' ? null : (selectedElementId ?? this.selectedElementId),
      selectedSlotId: selectedSlotId == '' ? null : (selectedSlotId ?? this.selectedSlotId),
      canvasZoom: canvasZoom ?? this.canvasZoom,
      canvasPan: canvasPan ?? this.canvasPan,
      isGridOverlay: isGridOverlay ?? this.isGridOverlay,
      isSnapToGuides: isSnapToGuides ?? this.isSnapToGuides,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CollageEditorNotifier extends Notifier<CollageEditorState> {
  final ProjectService _projectService = ProjectService();
  final _uuid = const Uuid();

  @override
  CollageEditorState build() {
    return CollageEditorState();
  }

  // Initialize a new project
  void initNewProject({String? templateId, double aspectRatio = 1.0}) {
    final projectId = _uuid.v4();
    List<CollageSlot> slots = [];

    if (templateId != null) {
      final template = CollageTemplate.builtInTemplates.firstWhere((t) => t.id == templateId);
      slots = template.slots.map((rect) {
        return CollageSlot(
          id: _uuid.v4(),
          rect: rect,
        );
      }).toList();
    }

    final newProject = CollageProject(
      id: projectId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      aspectRatio: aspectRatio,
      templateId: templateId,
      slots: slots,
    );

    state = CollageEditorState(
      project: newProject,
      undoStack: [],
      redoStack: [],
    );

    _autoSave();
  }

  // Load an existing project
  Future<void> loadProject(String projectId) async {
    state = state.copyWith(isLoading: true);
    try {
      final project = await _projectService.getProjectById(projectId);
      if (project != null) {
        state = CollageEditorState(
          project: project,
          undoStack: [],
          redoStack: [],
        );
      }
    } catch (e) {
      debugPrint('Error loading project: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // Auto save helper
  void _autoSave() {
    final proj = state.project;
    if (proj != null) {
      _projectService.saveProject(proj);
    }
  }

  // Push the current state to the undo stack before any modification
  void _saveToUndoStack() {
    final proj = state.project;
    if (proj != null) {
      final updatedUndo = List<CollageProject>.from(state.undoStack)..add(proj);
      // Limit undo history to 30 items
      if (updatedUndo.length > 30) {
        updatedUndo.removeAt(0);
      }
      state = state.copyWith(
        undoStack: updatedUndo,
        redoStack: [], // Clear redo stack on new operation
      );
    }
  }

  // Undo operation
  void undo() {
    if (state.undoStack.isEmpty) return;

    final updatedUndo = List<CollageProject>.from(state.undoStack);
    final previousProjectState = updatedUndo.removeLast();

    final currentProject = state.project;
    final updatedRedo = List<CollageProject>.from(state.redoStack);
    if (currentProject != null) {
      updatedRedo.add(currentProject);
    }

    state = state.copyWith(
      project: previousProjectState,
      undoStack: updatedUndo,
      redoStack: updatedRedo,
      selectedElementId: '', // Deselect on undo to avoid invalid selections
      selectedSlotId: '',
    );
    _autoSave();
  }

  // Redo operation
  void redo() {
    if (state.redoStack.isEmpty) return;

    final updatedRedo = List<CollageProject>.from(state.redoStack);
    final nextProjectState = updatedRedo.removeLast();

    final currentProject = state.project;
    final updatedUndo = List<CollageProject>.from(state.undoStack);
    if (currentProject != null) {
      updatedUndo.add(currentProject);
    }

    state = state.copyWith(
      project: nextProjectState,
      undoStack: updatedUndo,
      redoStack: updatedRedo,
      selectedElementId: '',
      selectedSlotId: '',
    );
    _autoSave();
  }

  // Select a freeform element
  void selectElement(String? elementId) {
    state = state.copyWith(
      selectedElementId: elementId ?? '',
      selectedSlotId: '', // Mutually exclusive
    );
  }

  // Select a grid template slot
  void selectSlot(String? slotId) {
    state = state.copyWith(
      selectedSlotId: slotId ?? '',
      selectedElementId: '', // Mutually exclusive
    );
  }

  // Change Aspect Ratio
  void changeAspectRatio(double ratio) {
    final proj = state.project;
    if (proj == null || proj.aspectRatio == ratio) return;

    _saveToUndoStack();
    state = state.copyWith(
      project: proj.copyWith(aspectRatio: ratio),
    );
    _autoSave();
  }

  // Change Background Type/Values
  void updateBackground(CollageBackground background) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();
    state = state.copyWith(
      project: proj.copyWith(background: background),
    );
    _autoSave();
  }

  // Update Grid Borders and Radius
  void updateGridBorders({double? spacing, double? cornerRadius, int? borderColor}) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();
    state = state.copyWith(
      project: proj.copyWith(
        gridSpacing: spacing ?? proj.gridSpacing,
        gridCornerRadius: cornerRadius ?? proj.gridCornerRadius,
        gridBorderColor: borderColor ?? proj.gridBorderColor,
      ),
    );
    _autoSave();
  }

  // Switch Templates
  void switchTemplate(String? templateId) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();

    // Use the photo pool to populate the new template slots so no image is lost!
    final List<CollageElement> photoPool = proj.photoPool;

    List<CollageSlot> newSlots = [];
    if (templateId != null) {
      final template = CollageTemplate.builtInTemplates.firstWhere((t) => t.id == templateId);
      
      for (int i = 0; i < template.slots.length; i++) {
        final rect = template.slots[i];
        CollageElement? photo;
        if (i < photoPool.length && photoPool[i].imagePath != null) {
          photo = photoPool[i];
        }
        newSlots.add(CollageSlot(
          id: _uuid.v4(),
          rect: rect,
          photo: photo,
        ));
      }
    }

    state = state.copyWith(
      project: proj.copyWith(
        templateId: templateId,
        slots: newSlots,
      ),
      selectedSlotId: '',
      selectedElementId: '',
    );
    _autoSave();
  }

  // Set/Update photo in a specific Slot
  void setSlotPhoto(String slotId, String imagePath) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();

    final newPhotoElement = CollageElement(
      id: _uuid.v4(),
      type: 'photo',
      imagePath: imagePath,
      width: 200, // Normalized default size
      height: 200,
    );

    final updatedSlots = proj.slots.map((slot) {
      if (slot.id == slotId) {
        return slot.copyWith(photo: newPhotoElement);
      }
      return slot;
    }).toList();

    // Sync to photo pool based on the index of the slot
    final List<CollageElement> updatedPool = List.from(proj.photoPool);
    final slotIndex = proj.slots.indexWhere((s) => s.id == slotId);
    if (slotIndex != -1) {
      if (slotIndex < updatedPool.length) {
        updatedPool[slotIndex] = newPhotoElement;
      } else {
        while (updatedPool.length < slotIndex) {
          updatedPool.add(const CollageElement(id: '', type: 'photo'));
        }
        updatedPool.add(newPhotoElement);
      }
    }

    state = state.copyWith(
      project: proj.copyWith(
        slots: updatedSlots,
        photoPool: updatedPool,
      ),
    );
    _autoSave();
  }

  // Remove photo from slot
  void clearSlotPhoto(String slotId) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();

    final updatedSlots = proj.slots.map((slot) {
      if (slot.id == slotId) {
        return CollageSlot(
          id: slot.id,
          rect: slot.rect,
          photo: null,
        );
      }
      return slot;
    }).toList();

    // Clear in pool as well
    final List<CollageElement> updatedPool = List.from(proj.photoPool);
    final slotIndex = proj.slots.indexWhere((s) => s.id == slotId);
    if (slotIndex != -1 && slotIndex < updatedPool.length) {
      updatedPool[slotIndex] = const CollageElement(id: '', type: 'photo');
    }

    state = state.copyWith(
      project: proj.copyWith(
        slots: updatedSlots,
        photoPool: updatedPool,
      ),
      selectedSlotId: '',
    );
    _autoSave();
  }

  // Update photo panning and zooming within a slot
  void updateSlotPhotoTransform(String slotId, {double? scale, double? panX, double? panY}) {
    final proj = state.project;
    if (proj == null) return;

    // We do NOT save to undo stack during active dragging/gestures for performance.
    // Instead, we update the state directly, and let the user commit on gesture end.
    final updatedSlots = proj.slots.map((slot) {
      if (slot.id == slotId && slot.photo != null) {
        final currentPhoto = slot.photo!;
        final updatedPhoto = currentPhoto.copyWith(
          scale: scale ?? currentPhoto.scale,
          panX: panX ?? currentPhoto.panX,
          panY: panY ?? currentPhoto.panY,
        );
        return slot.copyWith(photo: updatedPhoto);
      }
      return slot;
    }).toList();

    state = state.copyWith(
      project: proj.copyWith(slots: updatedSlots),
    );
  }

  // Apply non-destructive photo adjustments for Slot or Freeform Photos
  void updatePhotoEditingProperties(String id, {
    double? brightness,
    double? contrast,
    double? saturation,
    double? exposure,
    double? blur,
    double? sharpen,
    bool? flipHorizontal,
    bool? flipVertical,
    double? borderWidth,
    int? borderColor,
    double? borderRadius,
  }) {
    final proj = state.project;
    if (proj == null) return;

    // Check if it is a slot photo or a free element
    bool isSlot = proj.slots.any((s) => s.id == id || (s.photo != null && s.photo!.id == id));

    _saveToUndoStack();

    if (isSlot) {
      final updatedSlots = proj.slots.map((slot) {
        if (slot.id == id || (slot.photo != null && slot.photo!.id == id)) {
          final currentPhoto = slot.photo!;
          return slot.copyWith(
            photo: currentPhoto.copyWith(
              brightness: brightness ?? currentPhoto.brightness,
              contrast: contrast ?? currentPhoto.contrast,
              saturation: saturation ?? currentPhoto.saturation,
              exposure: exposure ?? currentPhoto.exposure,
              blur: blur ?? currentPhoto.blur,
              sharpen: sharpen ?? currentPhoto.sharpen,
              flipHorizontal: flipHorizontal ?? currentPhoto.flipHorizontal,
              flipVertical: flipVertical ?? currentPhoto.flipVertical,
              borderWidth: borderWidth ?? currentPhoto.borderWidth,
              borderColor: borderColor ?? currentPhoto.borderColor,
              borderRadius: borderRadius ?? currentPhoto.borderRadius,
            ),
          );
        }
        return slot;
      }).toList();

      state = state.copyWith(
        project: proj.copyWith(slots: updatedSlots),
      );
    } else {
      // Freeform element
      final updatedElements = proj.freeElements.map((el) {
        if (el.id == id) {
          return el.copyWith(
            brightness: brightness ?? el.brightness,
            contrast: contrast ?? el.contrast,
            saturation: saturation ?? el.saturation,
            exposure: exposure ?? el.exposure,
            blur: blur ?? el.blur,
            sharpen: sharpen ?? el.sharpen,
            flipHorizontal: flipHorizontal ?? el.flipHorizontal,
            flipVertical: flipVertical ?? el.flipVertical,
            borderWidth: borderWidth ?? el.borderWidth,
            borderColor: borderColor ?? el.borderColor,
            borderRadius: borderRadius ?? el.borderRadius,
          );
        }
        return el;
      }).toList();

      state = state.copyWith(
        project: proj.copyWith(freeElements: updatedElements),
      );
    }

    _autoSave();
  }

  // Add a freeform Photo element
  void addFreePhoto(String imagePath) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();

    final newElement = CollageElement(
      id: _uuid.v4(),
      type: 'photo',
      imagePath: imagePath,
      x: 100.0,
      y: 100.0,
      width: 200.0,
      height: 200.0,
      zIndex: proj.freeElements.length,
    );

    state = state.copyWith(
      project: proj.copyWith(
        freeElements: [...proj.freeElements, newElement],
      ),
      selectedElementId: newElement.id,
    );
    _autoSave();
  }

  // Add a freeform Text element
  void addFreeText({String text = 'Tap to Edit', String fontFamily = 'Inter', int color = 0xFFFFFFFF}) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();

    final newElement = CollageElement(
      id: _uuid.v4(),
      type: 'text',
      text: text,
      fontFamily: fontFamily,
      textColor: color,
      x: 100.0,
      y: 150.0,
      width: 250.0,
      height: 60.0,
      zIndex: proj.freeElements.length,
    );

    state = state.copyWith(
      project: proj.copyWith(
        freeElements: [...proj.freeElements, newElement],
      ),
      selectedElementId: newElement.id,
    );
    _autoSave();
  }

  // Add a Sticker element
  void addFreeSticker(String stickerType, String stickerValue) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();

    final newElement = CollageElement(
      id: _uuid.v4(),
      type: 'sticker',
      stickerType: stickerType,
      stickerValue: stickerValue,
      x: 150.0,
      y: 150.0,
      width: 100.0,
      height: 100.0,
      zIndex: proj.freeElements.length,
    );

    state = state.copyWith(
      project: proj.copyWith(
        freeElements: [...proj.freeElements, newElement],
      ),
      selectedElementId: newElement.id,
    );
    _autoSave();
  }

  // Update position, scale, angle of a freeform element (during active dragging/pinch)
  void updateElementTransform(String elementId, {
    double? x,
    double? y,
    double? width,
    double? height,
    double? angle,
    double? opacity,
  }) {
    final proj = state.project;
    if (proj == null) return;

    final updatedElements = proj.freeElements.map((el) {
      if (el.id == elementId) {
        return el.copyWith(
          x: x ?? el.x,
          y: y ?? el.y,
          width: width ?? el.width,
          height: height ?? el.height,
          angle: angle ?? el.angle,
          opacity: opacity ?? el.opacity,
        );
      }
      return el;
    }).toList();

    state = state.copyWith(
      project: proj.copyWith(freeElements: updatedElements),
    );
  }

  // Triggered on gesture end to commit the drag/scale changes to undo history
  void commitTransform() {
    _saveToUndoStack();
    _autoSave();
  }

  // Update properties of a text element
  void updateTextProperties(String elementId, {
    String? text,
    String? fontFamily,
    double? fontSize,
    int? textColor,
    bool? isBold,
    bool? isItalic,
    bool? hasShadow,
    int? shadowColor,
    String? alignment,
  }) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();

    final updatedElements = proj.freeElements.map((el) {
      if (el.id == elementId && el.type == 'text') {
        return el.copyWith(
          text: text ?? el.text,
          fontFamily: fontFamily ?? el.fontFamily,
          fontSize: fontSize ?? el.fontSize,
          textColor: textColor ?? el.textColor,
          isBold: isBold ?? el.isBold,
          isItalic: isItalic ?? el.isItalic,
          hasShadow: hasShadow ?? el.hasShadow,
          shadowColor: shadowColor ?? el.shadowColor,
          alignment: alignment ?? el.alignment,
        );
      }
      return el;
    }).toList();

    state = state.copyWith(
      project: proj.copyWith(freeElements: updatedElements),
    );
    _autoSave();
  }

  // Duplicate an element
  void duplicateElement(String elementId) {
    final proj = state.project;
    if (proj == null) return;

    final original = proj.freeElements.firstWhere((e) => e.id == elementId);
    _saveToUndoStack();

    final duplicate = original.copyWith(
      id: _uuid.v4(),
      x: original.x + 20.0, // Offset it slightly so the user sees it
      y: original.y + 20.0,
      zIndex: proj.freeElements.length,
    );

    state = state.copyWith(
      project: proj.copyWith(
        freeElements: [...proj.freeElements, duplicate],
      ),
      selectedElementId: duplicate.id,
    );
    _autoSave();
  }

  // Delete element
  void deleteElement(String elementId) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();

    final updatedElements = proj.freeElements
        .where((e) => e.id != elementId)
        .toList();

    state = state.copyWith(
      project: proj.copyWith(freeElements: updatedElements),
      selectedElementId: '',
    );
    _autoSave();
  }

  // Bring forward / send backward
  void bringToFront(String elementId) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();

    final elements = List<CollageElement>.from(proj.freeElements);
    final index = elements.indexWhere((e) => e.id == elementId);
    if (index != -1) {
      final element = elements.removeAt(index);
      elements.add(element); // Append at the end (renders last / on top)
      
      // Update zIndexes
      for (int i = 0; i < elements.length; i++) {
        elements[i] = elements[i].copyWith(zIndex: i);
      }

      state = state.copyWith(
        project: proj.copyWith(freeElements: elements),
      );
      _autoSave();
    }
  }

  void sendToBack(String elementId) {
    final proj = state.project;
    if (proj == null) return;

    _saveToUndoStack();

    final elements = List<CollageElement>.from(proj.freeElements);
    final index = elements.indexWhere((e) => e.id == elementId);
    if (index != -1) {
      final element = elements.removeAt(index);
      elements.insert(0, element); // Prepend at start (renders first / on bottom)

      // Update zIndexes
      for (int i = 0; i < elements.length; i++) {
        elements[i] = elements[i].copyWith(zIndex: i);
      }

      state = state.copyWith(
        project: proj.copyWith(freeElements: elements),
      );
      _autoSave();
    }
  }

  // Toggle Grid overlays
  void toggleGridOverlay() {
    state = state.copyWith(isGridOverlay: !state.isGridOverlay);
  }

  // Toggle Snapping helpers
  void toggleSnapToGuides() {
    state = state.copyWith(isSnapToGuides: !state.isSnapToGuides);
  }

  // Zoom canvas
  void setCanvasZoom(double zoom) {
    state = state.copyWith(canvasZoom: zoom.clamp(0.5, 4.0));
  }

  // Pan canvas
  void setCanvasPan(Offset pan) {
    state = state.copyWith(canvasPan: pan);
  }

  // Reset Canvas Zoom and Pan
  void resetCanvasView() {
    state = state.copyWith(canvasZoom: 1.0, canvasPan: Offset.zero);
  }

  // Rename Project
  void renameProject(String newTitle) {
    final proj = state.project;
    if (proj == null) return;

    state = state.copyWith(
      project: proj.copyWith(title: newTitle),
    );
    _autoSave();
  }

  // Update Project Thumbnail Path
  void updateThumbnailPath(String path) {
    final proj = state.project;
    if (proj == null) return;

    state = state.copyWith(
      project: proj.copyWith(thumbnailPath: path),
    );
    _autoSave();
  }
}

// Provider for editor state
final collageEditorProvider = NotifierProvider<CollageEditorNotifier, CollageEditorState>(() {
  return CollageEditorNotifier();
});
