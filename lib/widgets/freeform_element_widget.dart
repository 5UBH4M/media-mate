import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../features/collage_editor/models/collage_project.dart';

class FreeformElementWidget extends StatelessWidget {
  final CollageElement element;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(double dx, double dy) onDrag;
  final Function(double width, double height, double dx, double dy) onResize;
  final Function(double angle) onRotate;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onDragEnd;
  final Widget child;

  const FreeformElementWidget({
    super.key,
    required this.element,
    required this.isSelected,
    required this.onTap,
    required this.onDrag,
    required this.onResize,
    required this.onRotate,
    required this.onDelete,
    required this.onDuplicate,
    required this.onDragEnd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // We render the element inside a positioned stack element.
    // The angle rotation is applied via Transform.rotate.
    final double angle = element.angle;
    
    // Add extra padding for handles if selected
    final double handleSize = 28.0;
    final double halfHandle = handleSize / 2;

    Widget content = GestureDetector(
      onTap: onTap,
      onPanUpdate: (details) {
        onDrag(details.delta.dx, details.delta.dy);
      },
      onPanEnd: (_) => onDragEnd(),
      child: Container(
        width: element.width,
        height: element.height,
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2.0)
              : Border.all(color: Colors.transparent, width: 2.0),
        ),
        child: Opacity(
          opacity: element.opacity,
          child: child,
        ),
      ),
    );

    if (!isSelected) {
      return Positioned(
        left: element.x,
        top: element.y,
        child: Transform.rotate(
          angle: angle,
          child: content,
        ),
      );
    }

    // Wrap content in stack to render handles
    return Positioned(
      left: element.x - halfHandle,
      top: element.y - halfHandle,
      child: Transform.rotate(
        angle: angle,
        child: SizedBox(
          // Add padding for handles
          width: element.width + handleSize,
          height: element.height + handleSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Content in center
              Positioned(
                left: halfHandle,
                top: halfHandle,
                child: content,
              ),

              // Top-Left: Delete Handle
              Positioned(
                left: 0,
                top: 0,
                child: _buildHandle(
                  icon: Icons.close,
                  color: Colors.redAccent,
                  onTap: onDelete,
                ),
              ),

              // Bottom-Left: Duplicate Handle
              Positioned(
                left: 0,
                bottom: 0,
                child: _buildHandle(
                  icon: Icons.copy,
                  color: Colors.blueAccent,
                  onTap: onDuplicate,
                ),
              ),

              // Top-Center: Rotate Handle
              Positioned(
                left: (element.width + handleSize) / 2 - halfHandle,
                top: 0,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    // Calculate center of the element in global-ish space
                    final center = Offset(
                      element.x + element.width / 2,
                      element.y + element.height / 2,
                    );
                    
                    // We need to calculate the angle from the center to current touch point
                    final touchPos = details.globalPosition;
                    
                    // Adjust details.localPosition or calculate angle delta
                    final dx = touchPos.dx - center.dx;
                    final dy = touchPos.dy - center.dy;
                    
                    // Rotate -90 degrees because handle is at top
                    final double newAngle = math.atan2(dy, dx) + (math.pi / 2);
                    onRotate(newAngle);
                  },
                  onPanEnd: (_) => onDragEnd(),
                  child: _buildHandleWidget(
                    icon: Icons.rotate_right,
                    color: Colors.amber,
                  ),
                ),
              ),

              // Bottom-Right: Resize Handle
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    // In simple resize, drag delta changes width and height.
                    // We rotate the delta to align with the element's angle.
                    final cosA = math.cos(-angle);
                    final sinA = math.sin(-angle);
                    
                    // Localize drag delta
                    final dx = details.delta.dx * cosA - details.delta.dy * sinA;
                    final dy = details.delta.dx * sinA + details.delta.dy * cosA;

                    onResize(
                      element.width,
                      element.height,
                      dx,
                      dy,
                    );
                  },
                  onPanEnd: (_) => onDragEnd(),
                  child: _buildHandleWidget(
                    icon: Icons.open_in_full,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _buildHandleWidget(icon: icon, color: color),
    );
  }

  Widget _buildHandleWidget({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}
