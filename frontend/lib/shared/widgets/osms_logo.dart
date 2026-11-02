import 'package:flutter/material.dart';

/// The OSMS mark: many source threads converging into one story thread (the app's own
/// story art), on its ink square. The same drawing as the app icons in
/// frontend/assets/brand; below 48 px, their simplified version (three threads), as four
/// thin ones vanish. Brand colours, the same in light and dark.
class OsmsLogo extends StatelessWidget {
  const OsmsLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'OSMS',
    child: CustomPaint(size: Size.square(size), painter: _LogoPainter(simplified: size < 48)),
  );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.simplified});

  final bool simplified;

  static const _paper = Color(0xFFF7F6F3);
  static const _violet = Color(0xFF6440C8);
  static const _inks = [Color(0xFFB9A2FF), Color(0xFFA3B1C8), Color(0xFFE3A3B5), Color(0xFFC3B3DB)];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final square = Offset.zero & Size.square(side);
    // osms-favicon.svg's corners on a 1024 square; osms-icon.svg's body is 824 with 185.
    final corner = side * (simplified ? 224 / 1024 : 185 / 824);
    canvas.drawRRect(
      RRect.fromRectAndRadius(square, Radius.circular(corner)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2D2A37), Color(0xFF17161B)],
        ).createShader(square),
    );
    canvas.save();
    if (simplified) {
      canvas.scale(side / 1024);
    } else {
      canvas
        ..scale(side / 824)
        ..translate(-100, -100); // The icon's body, without its margins.
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void thread(Path path, Color color, double width) => canvas.drawPath(
      path,
      stroke
        ..color = color
        ..strokeWidth = width,
    );
    final (node, ring, core) = simplified ? (const Offset(600, 512), 104.0, 48.0) : (const Offset(596, 512), 44.0, 20.0);
    if (simplified) {
      thread(Path()..moveTo(150, 266)..cubicTo(380, 266, 430, 512, 600, 512), _inks[0], 84);
      thread(Path()..moveTo(150, 512)..lineTo(600, 512), _inks[1], 84);
      thread(Path()..moveTo(150, 758)..cubicTo(380, 758, 430, 512, 600, 512), _inks[2], 84);
      thread(Path()..moveTo(600, 512)..cubicTo(724, 512, 760, 466, 880, 466), _paper, 124);
    } else {
      thread(Path()..moveTo(196, 318)..cubicTo(380, 318, 452, 512, 596, 512), _inks[0], 24);
      thread(Path()..moveTo(196, 430)..cubicTo(360, 430, 470, 512, 596, 512), _inks[1], 24);
      thread(Path()..moveTo(196, 594)..cubicTo(360, 594, 470, 512, 596, 512), _inks[2], 24);
      thread(Path()..moveTo(196, 706)..cubicTo(380, 706, 452, 512, 596, 512), _inks[3], 24);
      thread(Path()..moveTo(596, 512)..cubicTo(690, 512, 730, 474, 828, 474), _paper, 48);
    }
    canvas
      ..drawCircle(node, ring, Paint()..color = _paper)
      ..drawCircle(node, core, Paint()..color = _violet)
      ..restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.simplified != simplified;
}
