// Every palette, light and dark (and pure black), must meet WCAG contrast:
// 4.5:1 for text, 3:1 for borders that carry meaning.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osms/core/theme/palettes.dart';
import 'package:osms/core/theme/tokens.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final variants = <String, OsmsColors>{
    for (final p in Palettes.all) ...{
      '${p.name} light': p.light,
      '${p.name} dark': p.dark,
      '${p.name} pure black': p.dark.pureBlack(),
    },
  };

  for (final MapEntry(key: name, value: c) in variants.entries) {
    group(name, () {
      final checks = <String, (Color, Color, double)>{
        'text on canvas': (c.text, c.canvas, 7),
        'text on surface': (c.text, c.surface, 7),
        'secondary text on canvas': (c.textSecondary, c.canvas, 4.5),
        'secondary text on surface': (c.textSecondary, c.surface, 4.5),
        'tertiary text on canvas': (c.textTertiary, c.canvas, 4.5),
        'tertiary text on surface': (c.textTertiary, c.surface, 4.5),
        'tertiary text on muted surface': (c.textTertiary, c.surfaceMuted, 4.5),
        'label on accent': (c.onAccent, c.accent, 4.5),
        'accent on surface': (c.accent, c.surface, 4.5),
        'text on accent soft (selection)': (c.text, c.accentSoft, 7),
        'new on surface': (c.newSignal, c.surface, 4.5),
        'new on new soft': (c.newSignal, c.newSignalSoft, 4.5),
        'text on new soft': (c.text, c.newSignalSoft, 7),
        'disagree on disagree soft': (c.disagree, c.disagreeSoft, 4.5),
        'text on avatar tints': (c.text, c.avatarTints.first, 4.5),
        'strong border on surface': (c.borderStrong, c.surface, 1.5),
      };
      for (final MapEntry(key: check, value: (fg, bg, min)) in checks.entries) {
        test(check, () {
          final ratio = contrast(fg, bg);
          expect(ratio, greaterThanOrEqualTo(min), reason: '$check is ${ratio.toStringAsFixed(2)}:1, needs $min:1');
        });
      }
      test('all avatar tints keep text readable', () {
        for (final tint in c.avatarTints) {
          expect(contrast(c.text, tint), greaterThanOrEqualTo(4.5));
        }
      });
    });
  }
}
