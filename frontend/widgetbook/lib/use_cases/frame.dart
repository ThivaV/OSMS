import 'package:flutter/material.dart';
import 'package:osms/core/theme/tokens.dart';

/// Puts a component on the app canvas, centred, padded and scrollable.
class Frame extends StatelessWidget {
  const Frame({super.key, required this.child, this.maxWidth = Sizes.cardMaxWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.canvas,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A vertical list of variants with small captions.
class Variants extends StatelessWidget {
  const Variants({super.key, required this.children});

  final Map<String, Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in children.entries) ...[
          Text(entry.key, style: context.text.caption.copyWith(color: c.textTertiary)),
          const SizedBox(height: Space.sm),
          entry.value,
          const SizedBox(height: Space.xl),
        ],
      ],
    );
  }
}
