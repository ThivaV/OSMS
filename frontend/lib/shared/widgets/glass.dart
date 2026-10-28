import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// A floating bar's surface: blurred backdrop, a high surface tint so text
/// stays readable, a hairline edge and a soft shadow. Use it only for chrome
/// that floats over content (mini player, story toolbar, phone tab bar).
class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.radius = Radii.pill, this.padding = EdgeInsets.zero});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final glass = context.glass;
    final shape = BorderRadius.circular(radius);
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: glass.tint),
        borderRadius: shape,
        border: Border.all(color: (dark ? Colors.white : Colors.black).withValues(alpha: dark ? 0.10 : 0.08)),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (!glass.isSolid) {
      body = BackdropFilter(filter: ImageFilter.blur(sigmaX: glass.blur, sigmaY: glass.blur), child: body);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.10),
            blurRadius: Space.xl,
            offset: const Offset(0, Space.sm),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: shape, child: body),
    );
  }
}
