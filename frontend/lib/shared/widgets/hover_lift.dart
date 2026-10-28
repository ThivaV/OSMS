import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Cards lift 2 px with a soft shadow on hover and settle to 98% on press.
/// Still when the system asks for reduced motion.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.radius = Radii.lg});

  final Widget child;
  final double radius;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final still = MediaQuery.disableAnimationsOf(context);
    final lifted = _hovered && !still;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: Motion.motionOf(context, Motion.hover),
          curve: Motion.standard,
          transform: Matrix4.translationValues(0, lifted ? -Space.xxs : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              if (lifted)
                BoxShadow(
                  color: c.text.withValues(alpha: 0.08),
                  blurRadius: Space.lg,
                  offset: const Offset(0, Space.xs),
                ),
            ],
          ),
          child: AnimatedScale(
            scale: _pressed && !still ? 0.98 : 1,
            duration: Motion.motionOf(context, Motion.press),
            curve: Motion.standard,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
