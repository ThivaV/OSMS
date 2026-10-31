import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Story art: drawn threads until Muse Image provides an illustration.
/// One thread per source, all converging into a single story thread.
/// Deterministic per [seed]. Generated illustrations set [isIllustration] so
/// the required "Illustration" label shows; the fallback never carries it.
/// With [imageUrl], the illustration itself shows, cropped at [focus]; the
/// drawn art stands in while it loads and if it can't.
class StoryVisual extends StatelessWidget {
  const StoryVisual({
    super.key,
    required this.seed,
    this.threads = 7,
    this.aspectRatio = 16 / 9,
    this.isIllustration = false,
    this.imageUrl,
    this.focus = Alignment.center,
  });

  final int seed;

  /// Usually the story's source count, clamped to stay legible.
  final int threads;
  final double aspectRatio;

  /// True for Muse Image art. Shows the small mandated label.
  final bool isIllustration;
  final String? imageUrl;
  final Alignment focus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final art = AspectRatio(
      aspectRatio: aspectRatio,
      child: CustomPaint(
        painter: _ThreadsPainter(
          seed: seed,
          threads: threads.clamp(3, 12),
          inks: c.visualInks,
          ground: c.visualGround,
          ring: c.surface,
        ),
      ),
    );
    final url = imageUrl;
    if (!isIllustration) return ExcludeSemantics(child: art);
    if (url == null) return _labelled(context, art);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        alignment: focus,
        frameBuilder: (context, image, frame, sync) =>
            frame == null && !sync ? ExcludeSemantics(child: art) : _labelled(context, SizedBox.expand(child: image)),
        errorBuilder: (context, error, stack) => ExcludeSemantics(child: art),
      ),
    );
  }

  Widget _labelled(BuildContext context, Widget art) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      image: true,
      label: 'Illustration for this story',
      child: Stack(
        children: [
          art,
          Positioned(
            left: Space.md,
            bottom: Space.md,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: c.border),
              ),
              child: Text(
                'Illustration',
                style: t.caption.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadsPainter extends CustomPainter {
  _ThreadsPainter({
    required this.seed,
    required this.threads,
    required this.inks,
    required this.ground,
    required this.ring,
  });

  final int seed;
  final int threads;
  final List<Color> inks;
  final Color ground;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final w = size.width;
    final h = size.height;
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);

    final main = inks[seed.abs() % inks.length];
    final knot = Offset(w * (0.56 + rnd.nextDouble() * 0.14), h * (0.4 + rnd.nextDouble() * 0.2));
    canvas.drawCircle(
      knot,
      max(w, h) * 0.45,
      Paint()
        ..shader = RadialGradient(colors: [main.withValues(alpha: 0.14), main.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: knot, radius: max(w, h) * 0.45)),
    );

    for (var i = 0; i < threads; i++) {
      final startY = h * ((i + 0.5) / threads) + (rnd.nextDouble() - 0.5) * h * 0.06;
      final path = Path()
        ..moveTo(-4, startY)
        ..cubicTo(
          w * (0.16 + rnd.nextDouble() * 0.12),
          startY + (rnd.nextDouble() - 0.5) * h * 0.3,
          knot.dx - w * (0.14 + rnd.nextDouble() * 0.1),
          knot.dy + (startY - knot.dy) * 0.3,
          knot.dx,
          knot.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (1.4 + rnd.nextDouble() * 1.6) * (h / 120).clamp(0.6, 2.0)
          ..color = inks[(seed + i) % inks.length].withValues(alpha: 0.45 + rnd.nextDouble() * 0.4),
      );
    }

    final out = Path()
      ..moveTo(knot.dx, knot.dy)
      ..cubicTo(
        knot.dx + w * 0.12,
        knot.dy + (rnd.nextDouble() - 0.5) * h * 0.2,
        w * 0.9,
        knot.dy + (rnd.nextDouble() - 0.5) * h * 0.3,
        w + 4,
        knot.dy + (rnd.nextDouble() - 0.5) * h * 0.2,
      );
    canvas.drawPath(
      out,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.5 * (h / 120).clamp(0.6, 2.0)
        ..color = main,
    );
    final dot = 5.5 * (h / 120).clamp(0.7, 1.8);
    canvas.drawCircle(knot, dot + 2.5, Paint()..color = ring);
    canvas.drawCircle(knot, dot, Paint()..color = main);
  }

  @override
  bool shouldRepaint(_ThreadsPainter old) =>
      old.seed != seed || old.threads != threads || old.ground != ground || old.inks != inks || old.ring != ring;
}
