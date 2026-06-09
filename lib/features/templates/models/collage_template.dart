import '../../collage_editor/models/collage_project.dart';

class CollageTemplate {
  final String id;
  final String name;
  final String category;
  final List<NormalizedRect> slots;
  final double defaultAspectRatio;

  const CollageTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.slots,
    this.defaultAspectRatio = 1.0,
  });

  static const List<CollageTemplate> builtInTemplates = [
    // 1 Photo
    CollageTemplate(
      id: 'single',
      name: 'Single Canvas',
      category: '1 Photo',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 1.0, height: 1.0),
      ],
    ),
    
    // 2 Photos
    CollageTemplate(
      id: 'split_v',
      name: '2 Column Split',
      category: '2 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.5, height: 1.0),
        NormalizedRect(left: 0.5, top: 0.0, width: 0.5, height: 1.0),
      ],
    ),
    CollageTemplate(
      id: 'split_h',
      name: '2 Row Split',
      category: '2 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 1.0, height: 0.5),
        NormalizedRect(left: 0.0, top: 0.5, width: 1.0, height: 0.5),
      ],
    ),
    CollageTemplate(
      id: 'left_sidebar',
      name: 'Left Sidebar Split',
      category: '2 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.33, height: 1.0),
        NormalizedRect(left: 0.33, top: 0.0, width: 0.67, height: 1.0),
      ],
    ),
    CollageTemplate(
      id: 'top_header',
      name: 'Top Header Split',
      category: '2 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 1.0, height: 0.33),
        NormalizedRect(left: 0.0, top: 0.33, width: 1.0, height: 0.67),
      ],
    ),

    // 3 Photos
    CollageTemplate(
      id: 'v_3',
      name: '3 Columns',
      category: '3 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.333, height: 1.0),
        NormalizedRect(left: 0.333, top: 0.0, width: 0.333, height: 1.0),
        NormalizedRect(left: 0.666, top: 0.0, width: 0.334, height: 1.0),
      ],
    ),
    CollageTemplate(
      id: 'h_3',
      name: '3 Rows',
      category: '3 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 1.0, height: 0.333),
        NormalizedRect(left: 0.0, top: 0.333, width: 1.0, height: 0.333),
        NormalizedRect(left: 0.0, top: 0.666, width: 1.0, height: 0.334),
      ],
    ),
    CollageTemplate(
      id: 'left_large_3',
      name: 'Left Highlight',
      category: '3 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.5, height: 1.0),
        NormalizedRect(left: 0.5, top: 0.0, width: 0.5, height: 0.5),
        NormalizedRect(left: 0.5, top: 0.5, width: 0.5, height: 0.5),
      ],
    ),
    CollageTemplate(
      id: 'top_large_3',
      name: 'Top Highlight',
      category: '3 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 1.0, height: 0.5),
        NormalizedRect(left: 0.0, top: 0.5, width: 0.5, height: 0.5),
        NormalizedRect(left: 0.5, top: 0.5, width: 0.5, height: 0.5),
      ],
    ),
    CollageTemplate(
      id: 'grid_3_asym',
      name: 'Bottom Highlight',
      category: '3 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.5, height: 0.5),
        NormalizedRect(left: 0.5, top: 0.0, width: 0.5, height: 0.5),
        NormalizedRect(left: 0.0, top: 0.5, width: 1.0, height: 0.5),
      ],
    ),

    // 4 Photos
    CollageTemplate(
      id: 'grid_4',
      name: '2x2 Grid',
      category: '4 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.5, height: 0.5),
        NormalizedRect(left: 0.5, top: 0.0, width: 0.5, height: 0.5),
        NormalizedRect(left: 0.0, top: 0.5, width: 0.5, height: 0.5),
        NormalizedRect(left: 0.5, top: 0.5, width: 0.5, height: 0.5),
      ],
    ),
    CollageTemplate(
      id: 'v_4',
      name: '4 Columns',
      category: '4 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.25, height: 1.0),
        NormalizedRect(left: 0.25, top: 0.0, width: 0.25, height: 1.0),
        NormalizedRect(left: 0.5, top: 0.0, width: 0.25, height: 1.0),
        NormalizedRect(left: 0.75, top: 0.0, width: 0.25, height: 1.0),
      ],
    ),
    CollageTemplate(
      id: 'h_4',
      name: '4 Rows',
      category: '4 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 1.0, height: 0.25),
        NormalizedRect(left: 0.0, top: 0.25, width: 1.0, height: 0.25),
        NormalizedRect(left: 0.0, top: 0.5, width: 1.0, height: 0.25),
        NormalizedRect(left: 0.0, top: 0.75, width: 1.0, height: 0.25),
      ],
    ),
    CollageTemplate(
      id: 'left_large_4',
      name: 'Left Large Quad',
      category: '4 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.5, height: 1.0),
        NormalizedRect(left: 0.5, top: 0.0, width: 0.5, height: 0.333),
        NormalizedRect(left: 0.5, top: 0.333, width: 0.5, height: 0.333),
        NormalizedRect(left: 0.5, top: 0.666, width: 0.5, height: 0.334),
      ],
    ),
    CollageTemplate(
      id: 'top_large_4',
      name: 'Top Large Quad',
      category: '4 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 1.0, height: 0.5),
        NormalizedRect(left: 0.0, top: 0.5, width: 0.333, height: 0.5),
        NormalizedRect(left: 0.333, top: 0.5, width: 0.333, height: 0.5),
        NormalizedRect(left: 0.666, top: 0.5, width: 0.334, height: 0.5),
      ],
    ),

    // 6 Photos
    CollageTemplate(
      id: 'grid_6_v',
      name: '2x3 Grid',
      category: '6 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.5, height: 0.333),
        NormalizedRect(left: 0.5, top: 0.0, width: 0.5, height: 0.333),
        NormalizedRect(left: 0.0, top: 0.333, width: 0.5, height: 0.333),
        NormalizedRect(left: 0.5, top: 0.333, width: 0.5, height: 0.333),
        NormalizedRect(left: 0.0, top: 0.666, width: 0.5, height: 0.334),
        NormalizedRect(left: 0.5, top: 0.666, width: 0.5, height: 0.334),
      ],
    ),
    CollageTemplate(
      id: 'grid_6_h',
      name: '3x2 Grid',
      category: '6 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.333, height: 0.5),
        NormalizedRect(left: 0.333, top: 0.0, width: 0.333, height: 0.5),
        NormalizedRect(left: 0.666, top: 0.0, width: 0.334, height: 0.5),
        NormalizedRect(left: 0.0, top: 0.5, width: 0.333, height: 0.5),
        NormalizedRect(left: 0.333, top: 0.5, width: 0.333, height: 0.5),
        NormalizedRect(left: 0.666, top: 0.5, width: 0.334, height: 0.5),
      ],
    ),
    CollageTemplate(
      id: 'asym_6',
      name: 'Asymmetric 6',
      category: '6 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.666, height: 0.666),
        NormalizedRect(left: 0.666, top: 0.0, width: 0.334, height: 0.333),
        NormalizedRect(left: 0.666, top: 0.333, width: 0.334, height: 0.333),
        NormalizedRect(left: 0.0, top: 0.666, width: 0.333, height: 0.334),
        NormalizedRect(left: 0.333, top: 0.666, width: 0.333, height: 0.334),
        NormalizedRect(left: 0.666, top: 0.666, width: 0.334, height: 0.334),
      ],
    ),

    // 9 Photos
    CollageTemplate(
      id: 'grid_9',
      name: '3x3 Grid',
      category: '9 Photos',
      defaultAspectRatio: 1.0,
      slots: [
        NormalizedRect(left: 0.0, top: 0.0, width: 0.333, height: 0.333),
        NormalizedRect(left: 0.333, top: 0.0, width: 0.333, height: 0.333),
        NormalizedRect(left: 0.666, top: 0.0, width: 0.334, height: 0.333),
        NormalizedRect(left: 0.0, top: 0.333, width: 0.333, height: 0.333),
        NormalizedRect(left: 0.333, top: 0.333, width: 0.333, height: 0.333),
        NormalizedRect(left: 0.666, top: 0.333, width: 0.334, height: 0.333),
        NormalizedRect(left: 0.0, top: 0.666, width: 0.333, height: 0.334),
        NormalizedRect(left: 0.333, top: 0.666, width: 0.333, height: 0.334),
        NormalizedRect(left: 0.666, top: 0.666, width: 0.334, height: 0.334),
      ],
    ),

    // Instagram/Social Layouts
    CollageTemplate(
      id: 'ig_square_polaroid',
      name: 'Polaroid Style',
      category: 'Social Layouts',
      defaultAspectRatio: 0.8, // 4:5 vertical
      slots: [
        NormalizedRect(left: 0.08, top: 0.08, width: 0.84, height: 0.68),
      ],
    ),
    CollageTemplate(
      id: 'story_3_stacked',
      name: 'Story Staggered',
      category: 'Social Layouts',
      defaultAspectRatio: 0.5625, // 9:16
      slots: [
        NormalizedRect(left: 0.08, top: 0.06, width: 0.84, height: 0.27),
        NormalizedRect(left: 0.08, top: 0.36, width: 0.84, height: 0.27),
        NormalizedRect(left: 0.08, top: 0.66, width: 0.84, height: 0.27),
      ],
    ),
  ];
}
