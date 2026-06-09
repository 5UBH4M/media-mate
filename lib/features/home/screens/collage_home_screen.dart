import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/project_service.dart';
import '../../collage_editor/models/collage_project.dart';
import '../../collage_editor/state/collage_editor_state.dart';
import '../../templates/models/collage_template.dart';
import '../../collage_editor/screens/collage_editor_screen.dart';

class CollageHomeScreen extends ConsumerStatefulWidget {
  const CollageHomeScreen({super.key});

  @override
  ConsumerState<CollageHomeScreen> createState() => _CollageHomeScreenState();
}

class _CollageHomeScreenState extends ConsumerState<CollageHomeScreen> {
  final ProjectService _projectService = ProjectService();
  List<CollageProject> _recentProjects = [];
  bool _loadingProjects = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _loadingProjects = true);
    final projects = await _projectService.getAllProjects();
    setState(() {
      _recentProjects = projects;
      _loadingProjects = false;
    });
  }

  void _createNewCollage(String? templateId, double aspectRatio) {
    ref.read(collageEditorProvider.notifier).initNewProject(
          templateId: templateId,
          aspectRatio: aspectRatio,
        );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CollageEditorScreen(),
      ),
    ).then((_) => _loadProjects()); // Reload drafts on return
  }

  void _openProject(String projectId) {
    ref.read(collageEditorProvider.notifier).loadProject(projectId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CollageEditorScreen(),
      ),
    ).then((_) => _loadProjects());
  }

  Future<void> _deleteProject(String projectId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project?'),
        content: const Text('Are you sure you want to permanently delete this collage draft?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _projectService.deleteProject(projectId);
      _loadProjects();
    }
  }

  void _showCreateDialog() {
    double selectedRatio = 1.0; // Default square
    String? selectedTemplateId; // Default freeform

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create Collage',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 1. Aspect Ratio Selector
                  Text(
                    '1. Choose Canvas Aspect Ratio',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRatioOption(context, 'Square (1:1)', 1.0, Icons.crop_square, selectedRatio, (ratio) {
                          setModalState(() => selectedRatio = ratio);
                        }),
                        _buildRatioOption(context, 'Portrait (4:5)', 0.8, Icons.portrait, selectedRatio, (ratio) {
                          setModalState(() => selectedRatio = ratio);
                        }),
                        _buildRatioOption(context, 'Landscape (4:3)', 4/3, Icons.landscape, selectedRatio, (ratio) {
                          setModalState(() => selectedRatio = ratio);
                        }),
                        _buildRatioOption(context, 'Story (9:16)', 9/16, Icons.stay_current_portrait, selectedRatio, (ratio) {
                          setModalState(() => selectedRatio = ratio);
                        }),
                        _buildRatioOption(context, 'Widescreen (16:9)', 16/9, Icons.tv, selectedRatio, (ratio) {
                          setModalState(() => selectedRatio = ratio);
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Layout Template Selector
                  Text(
                    '2. Select Starting Layout Grid',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      itemCount: CollageTemplate.builtInTemplates.length + 1, // +1 for Freeform
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Freeform Option
                          final isSelected = selectedTemplateId == null;
                          return InkWell(
                            onTap: () => setModalState(() => selectedTemplateId = null),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2) : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.dashboard_customize_outlined,
                                    size: 32,
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Free Form',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // Built-in templates
                        final template = CollageTemplate.builtInTemplates[index - 1];
                        final isSelected = selectedTemplateId == template.id;
                        return InkWell(
                          onTap: () => setModalState(() => selectedTemplateId = template.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                                  width: isSelected ? 2.5 : 1,
                              ),
                              color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2) : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Small representation of grid layout
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade600, width: 1),
                                    borderRadius: BorderRadius.circular(4),
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ),
                                  child: Stack(
                                    children: template.slots.map((s) {
                                      return Positioned(
                                        left: s.left * 42,
                                        top: s.top * 42,
                                        width: s.width * 42,
                                        height: s.height * 42,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade500, width: 0.5),
                                            color: Colors.white12,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  template.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  // Create button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _createNewCollage(selectedTemplateId, selectedRatio);
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Start Designing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildRatioOption(
    BuildContext context,
    String name,
    double ratio,
    IconData icon,
    double selectedRatio,
    Function(double) onSelected,
  ) {
    final isSelected = selectedRatio == ratio;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ChoiceChip(
        label: Text(name),
        avatar: Icon(icon, size: 18, color: isSelected ? Theme.of(context).colorScheme.onPrimary : null),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) onSelected(ratio);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Collage Creator',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Create New Collage card
              InkWell(
                onTap: _showCreateDialog,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_to_photos,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Create New Collage',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pick a template or start freeform',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Recent Projects Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Drafts',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_recentProjects.isNotEmpty)
                    TextButton(
                      onPressed: _loadProjects,
                      child: const Text('Refresh'),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Recent Projects List/Grid
              Expanded(
                child: _loadingProjects
                    ? const Center(child: CircularProgressIndicator())
                    : _recentProjects.isEmpty
                        ? _buildEmptyState()
                        : GridView.builder(
                            itemCount: _recentProjects.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                            itemBuilder: (context, index) {
                              final proj = _recentProjects[index];
                              return _buildProjectCard(proj);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No projects yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new collage to see drafts here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(CollageProject project) {
    // Generate simple readable ratio string
    String ratioText = '1:1';
    if ((project.aspectRatio - 0.5625).abs() < 0.05) ratioText = '9:16';
    if ((project.aspectRatio - 0.8).abs() < 0.05) ratioText = '4:5';
    if ((project.aspectRatio - 1.33).abs() < 0.05) ratioText = '4:3';
    if ((project.aspectRatio - 1.77).abs() < 0.05) ratioText = '16:9';

    // Simple relative date formatting
    final diff = DateTime.now().difference(project.updatedAt);
    String dateStr = 'Just now';
    if (diff.inDays > 0) {
      dateStr = '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      dateStr = '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      dateStr = '${diff.inMinutes}m ago';
    }

    final hasImages = project.slots.any((s) => s.photo != null) || project.freeElements.any((e) => e.type == 'photo');
    final hasThumbnail = project.thumbnailPath != null && File(project.thumbnailPath!).existsSync();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openProject(project.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Preview / Placeholder
            Expanded(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasThumbnail
                        ? Image.file(
                            File(project.thumbnailPath!),
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Icon(
                              hasImages ? Icons.photo_library : Icons.grid_on,
                              size: 36,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ratioText,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteProject(project.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Info text
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                      ),
                      Text(
                        project.templateId != null ? 'Grid' : 'Freeform',
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
