import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../templates/models/collage_template.dart';
import '../models/collage_project.dart';
import '../state/collage_editor_state.dart';
import '../../../widgets/collage_canvas.dart';
import '../../../core/theme.dart';
import '../../../services/export_service.dart';
import '../../../services/project_service.dart';

class CollageEditorScreen extends ConsumerStatefulWidget {
  const CollageEditorScreen({super.key});

  @override
  ConsumerState<CollageEditorScreen> createState() => _CollageEditorScreenState();
}

class _CollageEditorScreenState extends ConsumerState<CollageEditorScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final ExportService _exportService = ExportService();
  final ImagePicker _imagePicker = ImagePicker();
  
  late final TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
  
  // Active primary tab when nothing is selected
  int _activePrimaryTab = 0; // 0: Grid Layout, 1: Background, 2: Borders, 3: Add Layers, 4: Export

  // Font choices
  final List<String> _fonts = [
    'Inter',
    'Roboto',
    'Montserrat',
    'Pacifico',
    'Playfair Display',
    'Caveat',
    'Fredoka',
    'Lobster',
  ];

  // Sticker list
  final List<String> _emojis = ['😄', '❤️', '✨', '🎉', '🔥', '🌈', '🚀', '🦄', '🍕', '🍩', '✈️', '🎈', '🧸', '🕶️', '🌟'];
  final List<String> _shapes = ['star', 'heart', 'circle', 'square', 'triangle', 'sun', 'moon', 'fire'];

  // Background gradient color lists
  final List<List<int>> _presetsGradients = [
    [0xFF8F93FF, 0xFF00E5FF],
    [0xFFFF5F6D, 0xFFFFC371],
    [0xFF11998E, 0xFF38EF7D],
    [0xFF7F00FF, 0xFFE100FF],
    [0xFF00C6FF, 0xFF0072FF],
    [0xFF3A1C71, 0xFFD76D77, 0xFFA8606B],
  ];

  final List<int> _presetColors = [
    0xFF121212, 0xFFFFFFFF, 0xFFEF5350, 0xFFEC407A, 0xFFAB47BC,
    0xFF7E57C2, 0xFF5C6BC0, 0xFF42A5F5, 0xFF26C6DA, 0xFF26A69A,
    0xFFD4E157, 0xFFFFCA28, 0xFFFFA726, 0xFF8D6E63, 0xFF78909C
  ];

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(collageEditorProvider);
    final project = editorState.project;

    if (project == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _saveThumbnailAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _buildEditableTitle(project),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saveThumbnailAndPop,
          ),
        actions: [
          // Undo
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: editorState.undoStack.isEmpty
                ? null
                : () => ref.read(collageEditorProvider.notifier).undo(),
            tooltip: 'Undo',
          ),
          // Redo
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: editorState.redoStack.isEmpty
                ? null
                : () => ref.read(collageEditorProvider.notifier).redo(),
            tooltip: 'Redo',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Helper Toolbar
          _buildHelperToolbar(editorState),

          // 2. Large Canvas Area (occupies most of screen)
          Expanded(
            child: _buildCanvasArea(project, editorState),
          ),

          // 3. Toolbar / Bottom Control Panel
          _buildBottomControlPanel(project, editorState),
        ],
      ),
    ),);
  }

  Widget _buildEditableTitle(CollageProject project) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxTitleWidth = constraints.maxWidth.isFinite 
            ? constraints.maxWidth 
            : (MediaQuery.of(context).size.width - 160);
        return InkWell(
          onTap: () {
            final textController = TextEditingController(text: project.title);
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Rename Collage'),
                content: TextField(
                  controller: textController,
                  decoration: const InputDecoration(hintText: 'Enter collage name'),
                  autofocus: true,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (textController.text.trim().isNotEmpty) {
                        ref.read(collageEditorProvider.notifier).renameProject(textController.text.trim());
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Rename'),
                  ),
                ],
              ),
            );
          },
          child: Container(
            constraints: BoxConstraints(maxWidth: maxTitleWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    project.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit, size: 16),
              ],
            ),
          ),
        );
      }
    );
  }

  // Top Helper Toolbar (grid snapping, grid helper overlay)
  Widget _buildHelperToolbar(CollageEditorState state) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Grid Overlay
          _buildHelperButton(
            icon: state.isGridOverlay ? Icons.grid_on : Icons.grid_off,
            label: 'Grid Assist',
            isSelected: state.isGridOverlay,
            onPressed: () => ref.read(collageEditorProvider.notifier).toggleGridOverlay(),
          ),
          
          // Snapping Guides
          _buildHelperButton(
            icon: state.isSnapToGuides ? Icons.align_horizontal_center : Icons.align_horizontal_center_outlined,
            label: 'Snap Guides',
            isSelected: state.isSnapToGuides,
            onPressed: () => ref.read(collageEditorProvider.notifier).toggleSnapToGuides(),
          ),
        ],
      ),
    );
  }

  Widget _buildHelperButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final color = isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  // Main interactive area centering the scaled canvas
  Widget _buildCanvasArea(CollageProject project, CollageEditorState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double padding = 32.0;
        final double maxWidth = constraints.maxWidth - padding;
        final double maxHeight = constraints.maxHeight - padding;

        final double ratio = project.aspectRatio;

        double canvasWidth, canvasHeight;
        if (maxWidth / maxHeight > ratio) {
          canvasHeight = maxHeight;
          canvasWidth = canvasHeight * ratio;
        } else {
          canvasWidth = maxWidth;
          canvasHeight = canvasWidth / ratio;
        }

        final canvasSize = Size(canvasWidth, canvasHeight);

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              // Disable InteractiveViewer gestures when editing a slot or element
              // so that child gestures (adjusting photos/dragging elements) are smooth and don't conflict.
              scaleEnabled: state.selectedSlotId == null && state.selectedElementId == null,
              panEnabled: state.selectedSlotId == null && state.selectedElementId == null,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CollageCanvas(
                    repaintBoundaryKey: _repaintBoundaryKey,
                    size: canvasSize,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Bottom Control Panel
  Widget _buildBottomControlPanel(CollageProject project, CollageEditorState state) {
    final bool isSlotSelected = state.selectedSlotId != null;
    final bool isElementSelected = state.selectedElementId != null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Tool Options Content
          Container(
            height: 180,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: isSlotSelected
                ? _buildSlotEditingToolbar(state.selectedSlotId!, project)
                : isElementSelected
                    ? _buildElementEditingToolbar(state.selectedElementId!, project)
                    : _buildPrimaryTabsContent(project),
          ),

          const Divider(height: 1, thickness: 0.5),

          // 2. Tab Selectors (only if nothing is selected)
          if (!isSlotSelected && !isElementSelected)
            NavigationBar(
              selectedIndex: _activePrimaryTab,
              onDestinationSelected: (idx) {
                setState(() => _activePrimaryTab = idx);
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.grid_on), label: 'Layouts'),
                NavigationDestination(icon: Icon(Icons.palette), label: 'Background'),
                NavigationDestination(icon: Icon(Icons.border_outer), label: 'Borders'),
                NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Layers'),
                NavigationDestination(icon: Icon(Icons.ios_share), label: 'Export'),
              ],
            ),
          
          // Contextual selected banner (gives a way to dismiss selection)
          if (isSlotSelected || isElementSelected)
            Container(
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSlotSelected ? 'Grid Cell Selected' : 'Layer Selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(collageEditorProvider.notifier).selectSlot(null);
                      ref.read(collageEditorProvider.notifier).selectElement(null);
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Deselect', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- 1. Primary Tab Options ---

  Widget _buildPrimaryTabsContent(CollageProject project) {
    switch (_activePrimaryTab) {
      case 0: // Layouts
        return _buildLayoutTemplatesTab(project);
      case 1: // Background
        return _buildBackgroundTab(project);
      case 2: // Borders
        return _buildBordersTab(project);
      case 3: // Layers
        return _buildAddLayersTab();
      case 4: // Export
        return _buildExportTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // Tab: Templates List
  Widget _buildLayoutTemplatesTab(CollageProject project) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: CollageTemplate.builtInTemplates.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) {
          // Freeform option
          final isSelected = project.templateId == null;
          return _buildToolbarItem(
            label: 'Freeform',
            isSelected: isSelected,
            onTap: () => ref.read(collageEditorProvider.notifier).switchTemplate(null),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.dashboard_customize_outlined),
            ),
          );
        }

        final template = CollageTemplate.builtInTemplates[idx - 1];
        final isSelected = project.templateId == template.id;
        return _buildToolbarItem(
          label: template.name,
          isSelected: isSelected,
          onTap: () => ref.read(collageEditorProvider.notifier).switchTemplate(template.id),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white24, width: isSelected ? 2 : 1),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white10,
            ),
            child: Stack(
              children: template.slots.map((s) {
                return Positioned(
                  left: s.left * 46,
                  top: s.top * 46,
                  width: s.width * 46,
                  height: s.height * 46,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade600, width: 0.5),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // Tab: Background Customize
  Widget _buildBackgroundTab(CollageProject project) {
    final bg = project.background;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Background type switch
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Solid'),
                  selected: bg.type == BackgroundType.solid,
                  onSelected: (_) => ref.read(collageEditorProvider.notifier).updateBackground(bg.copyWith(type: BackgroundType.solid)),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Gradient'),
                  selected: bg.type == BackgroundType.gradient,
                  onSelected: (_) => ref.read(collageEditorProvider.notifier).updateBackground(
                        bg.copyWith(
                          type: BackgroundType.gradient,
                          gradientColors: bg.gradientColors ?? _presetsGradients[0],
                        ),
                      ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Custom Image'),
                  selected: bg.type == BackgroundType.image,
                  onSelected: (_) async {
                    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      ref.read(collageEditorProvider.notifier).updateBackground(
                            bg.copyWith(type: BackgroundType.image, imagePath: image.path),
                          );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Presets lists
          if (bg.type == BackgroundType.solid)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _presetColors.length,
                itemBuilder: (context, idx) {
                  final colorVal = _presetColors[idx];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => ref.read(collageEditorProvider.notifier).updateBackground(bg.copyWith(solidColor: colorVal)),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54, width: bg.solidColor == colorVal ? 2.5 : 1),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (bg.type == BackgroundType.gradient)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _presetsGradients.length,
                itemBuilder: (context, idx) {
                  final colors = _presetsGradients[idx];
                  final isSelected = bg.gradientColors != null &&
                      bg.gradientColors!.length == colors.length &&
                      bg.gradientColors![0] == colors[0];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => ref.read(collageEditorProvider.notifier).updateBackground(bg.copyWith(gradientColors: colors)),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colors.map((c) => Color(c)).toList(),
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54, width: isSelected ? 2.5 : 1),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (bg.type == BackgroundType.image && bg.imagePath != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Blur background:'),
                  Expanded(
                    child: Slider(
                      value: bg.blurRadius,
                      min: 0,
                      max: 20,
                      divisions: 20,
                      onChanged: (val) {
                        ref.read(collageEditorProvider.notifier).updateBackground(bg.copyWith(blurRadius: val));
                      },
                    ),
                  ),
                  Text('${bg.blurRadius.round()}px'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Tab: Border & Spacing
  Widget _buildBordersTab(CollageProject project) {
    if (project.templateId == null) {
      return const Center(child: Text('Borders and Spacing are only active for Grid layouts.'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Spacing slider
          Row(
            children: [
              const SizedBox(width: 80, child: Text('Spacing:')),
              Expanded(
                child: Slider(
                  value: project.gridSpacing,
                  min: 0,
                  max: 30,
                  onChanged: (val) => ref.read(collageEditorProvider.notifier).updateGridBorders(spacing: val),
                ),
              ),
              Text('${project.gridSpacing.round()}'),
            ],
          ),
          // 2. Corner radius slider
          Row(
            children: [
              const SizedBox(width: 80, child: Text('Corners:')),
              Expanded(
                child: Slider(
                  value: project.gridCornerRadius,
                  min: 0,
                  max: 40,
                  onChanged: (val) => ref.read(collageEditorProvider.notifier).updateGridBorders(cornerRadius: val),
                ),
              ),
              Text('${project.gridCornerRadius.round()}'),
            ],
          ),
        ],
      ),
    );
  }

  // Tab: Add Elements (Layers)
  Widget _buildAddLayersTab() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildToolbarItem(
          label: 'Photo',
          child: const Icon(Icons.add_photo_alternate, size: 28),
          onTap: () async {
            final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              ref.read(collageEditorProvider.notifier).addFreePhoto(image.path);
            }
          },
        ),
        _buildToolbarItem(
          label: 'Text',
          child: const Icon(Icons.title, size: 28),
          onTap: () {
            ref.read(collageEditorProvider.notifier).addFreeText();
          },
        ),
        _buildToolbarItem(
          label: 'Stickers',
          child: const Icon(Icons.emoji_emotions, size: 28),
          onTap: _showStickerSheet,
        ),
      ],
    );
  }

  void _showStickerSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Emoji or Sticker', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              
              // Emojis list
              const Text('Emojis'),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojis.length,
                  itemBuilder: (context, idx) {
                    final emoji = _emojis[idx];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () {
                          ref.read(collageEditorProvider.notifier).addFreeSticker('emoji', emoji);
                          Navigator.pop(context);
                        },
                        child: Text(emoji, style: const TextStyle(fontSize: 32)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Shapes list
              const Text('Decorative Shapes'),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  itemCount: _shapes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, idx) {
                    final shape = _shapes[idx];
                    return InkWell(
                      onTap: () {
                        ref.read(collageEditorProvider.notifier).addFreeSticker('shape', shape);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white10,
                        ),
                        child: Center(
                          child: Icon(_getStickerIcon(shape), size: 28),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getStickerIcon(String value) {
    switch (value) {
      case 'star': return Icons.star;
      case 'heart': return Icons.favorite;
      case 'circle': return Icons.circle;
      case 'square': return Icons.crop_square;
      case 'triangle': return Icons.change_history;
      case 'sun': return Icons.wb_sunny;
      case 'moon': return Icons.dark_mode;
      case 'fire': return Icons.local_fire_department;
      default: return Icons.category;
    }
  }

  // Tab: Export
  Widget _buildExportTab() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildToolbarItem(
          label: 'Save PNG',
          child: const Icon(Icons.image, size: 28),
          onTap: () => _handleExport('png'),
        ),
        _buildToolbarItem(
          label: 'Save JPEG',
          child: const Icon(Icons.picture_as_pdf, size: 28), // Visual distinction
          onTap: () => _handleExport('jpeg'),
        ),
        _buildToolbarItem(
          label: 'Share',
          child: const Icon(Icons.share, size: 28),
          onTap: () => _handleShare(),
        ),
      ],
    );
  }

  Future<Uint8List?> _captureCanvas({double pixelRatio = 3.0}) async {
    try {
      // Allow any active push/pop dialog transitions to completely settle
      // (which typically takes 200-300ms in Flutter).
      await Future.delayed(const Duration(milliseconds: 350));
      
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      // Capture at specified scale (default 3.0x for premium exports, 1.0x for draft thumbnails)
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing canvas image: $e');
      return null;
    }
  }

  Future<void> _saveThumbnailAndPop() async {
    Uint8List? bytes;
    try {
      bytes = await _captureCanvas(pixelRatio: 1.0);
    } catch (e) {
      debugPrint('Error capturing canvas for thumbnail: $e');
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      if (bytes != null) {
        final docDir = await getApplicationDocumentsDirectory();
        final thumbDir = Directory('${docDir.path}/media_mate_projects/thumbnails');
        if (!await thumbDir.exists()) {
          await thumbDir.create(recursive: true);
        }
        final project = ref.read(collageEditorProvider).project;
        if (project != null) {
          final thumbFile = File('${thumbDir.path}/thumb_${project.id}.png');
          await thumbFile.writeAsBytes(bytes);
          // Update project with thumbnail path
          ref.read(collageEditorProvider.notifier).updateThumbnailPath(thumbFile.path);
          
          final updatedProject = ref.read(collageEditorProvider).project;
          if (updatedProject != null) {
            await ProjectService().saveProject(updatedProject);
          }
        }
      }
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
    }

    // Dismiss loader
    if (mounted) {
      Navigator.of(context).pop(); // Pops loader dialog
      Navigator.of(context).pop(); // Pops CollageEditorScreen
    }
  }

  Future<void> _handleExport(String format) async {
    // Prompt confirmation dialog
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Collage'),
        content: const Text(
          'Media Mate will save this image to your device storage under:\n'
          '• "Downloads/Media Mate/Collages" (on Desktop/Computer)\n'
          '• Photos/Gallery app under "Media Mate/Collages" album (on Android & iOS)\n\n'
          'Do you want to proceed?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow & Save'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // Show spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final bytes = await _captureCanvas();
    Navigator.pop(context); // Pop loading

    if (bytes == null) {
      _showSnackbar('Failed to compile collage.');
      return;
    }

    final savedPath = await _exportService.downloadCollage(bytes: bytes, format: format);
    if (savedPath != null) {
      _showSnackbar(savedPath.startsWith('Downloaded') ? savedPath : 'Saved collage to: $savedPath');
    } else {
      _showSnackbar('Failed to download collage.');
    }
  }

  Future<void> _handleShare() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final bytes = await _captureCanvas();
    Navigator.pop(context); // Pop loading

    if (bytes == null) {
      _showSnackbar('Failed to compile collage.');
      return;
    }

    final success = await _exportService.shareCollage(bytes: bytes, format: 'png');
    if (!success) {
      _showSnackbar('Failed to open share sheet.');
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 4),
    ));
  }

  // --- 2. Contextual Editing Toolbars ---

  // Contextual Photo Slot Editing
  Widget _buildSlotEditingToolbar(String slotId, CollageProject project) {
    final slot = project.slots.firstWhere((s) => s.id == slotId);
    final photo = slot.photo;

    if (photo == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Replace Photo
          _buildToolbarItem(
            label: 'Replace',
            child: const Icon(Icons.autorenew),
            onTap: () async {
              final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                ref.read(collageEditorProvider.notifier).setSlotPhoto(slot.id, image.path);
              }
            },
          ),
          
          // Image Adjustments
          _buildToolbarItem(
            label: 'Adjust',
            child: const Icon(Icons.tune),
            onTap: () => _showPhotoAdjustmentsSheet(photo.id, photo),
          ),

          // Flip Horizontal
          _buildToolbarItem(
            label: 'Flip H',
            isSelected: photo.flipHorizontal,
            child: const Icon(Icons.flip),
            onTap: () => ref.read(collageEditorProvider.notifier).updatePhotoEditingProperties(
                  photo.id,
                  flipHorizontal: !photo.flipHorizontal,
                ),
          ),

          // Flip Vertical
          _buildToolbarItem(
            label: 'Flip V',
            isSelected: photo.flipVertical,
            child: RotatedBox(quarterTurns: 1, child: const Icon(Icons.flip)),
            onTap: () => ref.read(collageEditorProvider.notifier).updatePhotoEditingProperties(
                  photo.id,
                  flipVertical: !photo.flipVertical,
                ),
          ),

          // Individual Rounded Corners slider
          _buildToolbarItem(
            label: 'Corners',
            child: const Icon(Icons.rounded_corner),
            onTap: () => _showRadiusSliderSheet(photo.id, photo.borderRadius),
          ),

          // Clear Photo
          _buildToolbarItem(
            label: 'Remove',
            child: const Icon(Icons.delete, color: Colors.redAccent),
            onTap: () => ref.read(collageEditorProvider.notifier).clearSlotPhoto(slot.id),
          ),
        ],
      ),
    );
  }

  // Contextual Freeform Layer Editing (Text, Stickers, Free Photos)
  Widget _buildElementEditingToolbar(String elementId, CollageProject project) {
    final element = project.freeElements.firstWhere(
      (e) => e.id == elementId,
      orElse: () => const CollageElement(id: '', type: ''),
    );

    if (element.id.isEmpty) return const SizedBox.shrink();

    // Elements common operations: Layer management (Bring front, send back), duplicate, delete
    final layerOps = [
      _buildToolbarItem(
        label: 'To Front',
        child: const Icon(Icons.vertical_align_top),
        onTap: () => ref.read(collageEditorProvider.notifier).bringToFront(element.id),
      ),
      _buildToolbarItem(
        label: 'To Back',
        child: const Icon(Icons.vertical_align_bottom),
        onTap: () => ref.read(collageEditorProvider.notifier).sendToBack(element.id),
      ),
      _buildToolbarItem(
        label: 'Opacity',
        child: const Icon(Icons.opacity),
        onTap: () => _showOpacitySliderSheet(element.id, element.opacity),
      ),
    ];

    if (element.type == 'photo') {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildToolbarItem(
              label: 'Adjust',
              child: const Icon(Icons.tune),
              onTap: () => _showPhotoAdjustmentsSheet(element.id, element),
            ),
            _buildToolbarItem(
              label: 'Flip H',
              isSelected: element.flipHorizontal,
              child: const Icon(Icons.flip),
              onTap: () => ref.read(collageEditorProvider.notifier).updatePhotoEditingProperties(
                    element.id,
                    flipHorizontal: !element.flipHorizontal,
                  ),
            ),
            _buildToolbarItem(
              label: 'Flip V',
              isSelected: element.flipVertical,
              child: RotatedBox(quarterTurns: 1, child: const Icon(Icons.flip)),
              onTap: () => ref.read(collageEditorProvider.notifier).updatePhotoEditingProperties(
                    element.id,
                    flipVertical: !element.flipVertical,
                  ),
            ),
            _buildToolbarItem(
              label: 'Corners',
              child: const Icon(Icons.rounded_corner),
              onTap: () => _showRadiusSliderSheet(element.id, element.borderRadius),
            ),
            ...layerOps,
          ],
        ),
      );
    }

    if (element.type == 'text') {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Edit text content
            _buildToolbarItem(
              label: 'Edit Text',
              child: const Icon(Icons.edit_note),
              onTap: () => _showTextContentDialog(element.id, element.text ?? ''),
            ),
            // Fonts
            _buildToolbarItem(
              label: 'Font',
              child: const Icon(Icons.font_download),
              onTap: () => _showFontPickerSheet(element.id, element.fontFamily),
            ),
            // Color
            _buildToolbarItem(
              label: 'Color',
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(element.textColor),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70),
                ),
              ),
              onTap: () => _showTextColorPickerSheet(element.id, element.textColor),
            ),
            // Size
            _buildToolbarItem(
              label: 'Size',
              child: const Icon(Icons.format_size),
              onTap: () => _showFontSizeSliderSheet(element.id, element.fontSize),
            ),
            // Bold
            _buildToolbarItem(
              label: 'Bold',
              isSelected: element.isBold,
              child: const Icon(Icons.format_bold),
              onTap: () => ref.read(collageEditorProvider.notifier).updateTextProperties(
                    element.id,
                    isBold: !element.isBold,
                  ),
            ),
            // Italic
            _buildToolbarItem(
              label: 'Italic',
              isSelected: element.isItalic,
              child: const Icon(Icons.format_italic),
              onTap: () => ref.read(collageEditorProvider.notifier).updateTextProperties(
                    element.id,
                    isItalic: !element.isItalic,
                  ),
            ),
            // Alignment
            _buildToolbarItem(
              label: 'Align',
              child: Icon(element.alignment == 'left'
                  ? Icons.format_align_left
                  : (element.alignment == 'right' ? Icons.format_align_right : Icons.format_align_center)),
              onTap: () {
                final nextAlign = element.alignment == 'center'
                    ? 'left'
                    : (element.alignment == 'left' ? 'right' : 'center');
                ref.read(collageEditorProvider.notifier).updateTextProperties(element.id, alignment: nextAlign);
              },
            ),
            // Shadow
            _buildToolbarItem(
              label: 'Shadow',
              isSelected: element.hasShadow,
              child: const Icon(Icons.text_fields),
              onTap: () => ref.read(collageEditorProvider.notifier).updateTextProperties(
                    element.id,
                    hasShadow: !element.hasShadow,
                  ),
            ),
            ...layerOps,
          ],
        ),
      );
    }

    if (element.type == 'sticker') {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ...layerOps,
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // --- Sub Editing bottom sheets/sliders ---

  // 1. Non-destructive adjustments slider sheet
  void _showPhotoAdjustmentsSheet(String id, CollageElement photo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final editorState = ref.watch(collageEditorProvider);
            final project = editorState.project!;
            
            // Resolve the live photo state
            CollageElement? livePhoto;
            final isSlot = project.slots.any((s) => s.id == id || (s.photo != null && s.photo!.id == id));
            if (isSlot) {
              final slot = project.slots.firstWhere((s) => s.id == id || (s.photo != null && s.photo!.id == id));
              livePhoto = slot.photo;
            } else {
              livePhoto = project.freeElements.firstWhere((e) => e.id == id, orElse: () => const CollageElement(id: '', type: 'photo'));
            }

            if (livePhoto == null) return const SizedBox.shrink();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Adjust Photo Filters', style: Theme.of(context).textTheme.titleLarge),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        // Brightness
                        _buildAdjustmentSlider(
                          label: 'Brightness',
                          value: livePhoto.brightness,
                          min: -1.0,
                          max: 1.0,
                          onChanged: (val) {
                            ref.read(collageEditorProvider.notifier).updatePhotoEditingProperties(id, brightness: val);
                          },
                        ),
                        // Contrast
                        _buildAdjustmentSlider(
                          label: 'Contrast',
                          value: livePhoto.contrast,
                          min: 0.0,
                          max: 2.0,
                          onChanged: (val) {
                            ref.read(collageEditorProvider.notifier).updatePhotoEditingProperties(id, contrast: val);
                          },
                        ),
                        // Saturation
                        _buildAdjustmentSlider(
                          label: 'Saturation',
                          value: livePhoto.saturation,
                          min: 0.0,
                          max: 2.0,
                          onChanged: (val) {
                            ref.read(collageEditorProvider.notifier).updatePhotoEditingProperties(id, saturation: val);
                          },
                        ),
                        // Exposure
                        _buildAdjustmentSlider(
                          label: 'Exposure',
                          value: livePhoto.exposure,
                          min: -1.0,
                          max: 1.0,
                          onChanged: (val) {
                            ref.read(collageEditorProvider.notifier).updatePhotoEditingProperties(id, exposure: val);
                          },
                        ),
                        // Blur
                        _buildAdjustmentSlider(
                          label: 'Blur',
                          value: livePhoto.blur,
                          min: 0.0,
                          max: 20.0,
                          onChanged: (val) {
                            ref.read(collageEditorProvider.notifier).updatePhotoEditingProperties(id, blur: val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdjustmentSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    // Show value as percentage/round number
    String displayVal = value.toStringAsFixed(1);
    if (label == 'Blur') displayVal = '${value.round()}px';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(displayVal, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // 2. Corner radius selector
  void _showRadiusSliderSheet(String id, double currentRadius) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final editorState = ref.watch(collageEditorProvider);
            final project = editorState.project!;
            
            double liveRadius = 0.0;
            final isSlot = project.slots.any((s) => s.id == id || (s.photo != null && s.photo!.id == id));
            if (isSlot) {
              final slot = project.slots.firstWhere((s) => s.id == id || (s.photo != null && s.photo!.id == id));
              liveRadius = slot.photo?.borderRadius ?? 0.0;
            } else {
              final el = project.freeElements.firstWhere((e) => e.id == id, orElse: () => const CollageElement(id: '', type: 'photo'));
              liveRadius = el.borderRadius;
            }

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adjust Corner Radius', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: liveRadius,
                          min: 0,
                          max: 100,
                          onChanged: (val) {
                            ref.read(collageEditorProvider.notifier).updatePhotoEditingProperties(id, borderRadius: val);
                          },
                        ),
                      ),
                      Text('${liveRadius.round()}px'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 3. Opacity selector
  void _showOpacitySliderSheet(String id, double currentOpacity) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final editorState = ref.watch(collageEditorProvider);
            final project = editorState.project!;
            final el = project.freeElements.firstWhere((e) => e.id == id, orElse: () => const CollageElement(id: '', type: ''));
            if (el.id.isEmpty) return const SizedBox.shrink();
            final double liveOpacity = el.opacity;

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adjust Element Opacity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: liveOpacity,
                          min: 0.1,
                          max: 1.0,
                          onChanged: (val) {
                            ref.read(collageEditorProvider.notifier).updateElementTransform(id, opacity: val);
                          },
                        ),
                      ),
                      Text('${(liveOpacity * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 4. Text Editor Dialog
  void _showTextContentDialog(String id, String currentText) {
    final controller = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Text Content'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Enter text here...'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(collageEditorProvider.notifier).updateTextProperties(id, text: controller.text);
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // 5. Font selector
  void _showFontPickerSheet(String id, String currentFont) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pick a Font Family', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _fonts.length,
                  itemBuilder: (context, idx) {
                    final font = _fonts[idx];
                    final isSelected = font == currentFont;
                    return ListTile(
                      title: Text(font, style: TextStyle(fontFamily: font, fontSize: 16)),
                      trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                      onTap: () {
                        ref.read(collageEditorProvider.notifier).updateTextProperties(id, fontFamily: font);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 6. Text color selector
  void _showTextColorPickerSheet(String id, int currentColor) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Text Color', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetColors.length,
                  itemBuilder: (context, idx) {
                    final colorVal = _presetColors[idx];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () {
                          ref.read(collageEditorProvider.notifier).updateTextProperties(id, textColor: colorVal);
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(colorVal),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: currentColor == colorVal ? 2.5 : 1),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // 7. Font size selector
  void _showFontSizeSliderSheet(String id, double currentSize) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final editorState = ref.watch(collageEditorProvider);
            final project = editorState.project!;
            final el = project.freeElements.firstWhere((e) => e.id == id, orElse: () => const CollageElement(id: '', type: ''));
            if (el.id.isEmpty) return const SizedBox.shrink();
            final double liveSize = el.fontSize;

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adjust Font Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: liveSize,
                          min: 12,
                          max: 96,
                          onChanged: (val) {
                            ref.read(collageEditorProvider.notifier).updateTextProperties(id, fontSize: val);
                          },
                        ),
                      ),
                      Text('${liveSize.round()}pt'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Generic item in bottom toolbar list
  Widget _buildToolbarItem({
    required String label,
    required Widget child,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurface,
                ),
                child: child,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
