import 'package:flutter/material.dart';
import 'package:osms/core/theme/tokens.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import 'frame.dart';

/// Colours, type and spacing in one place, so the system can be reviewed.
class DesignTokens extends StatelessWidget {
  const DesignTokens({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final swatches = {
      'Canvas': c.canvas,
      'Surface': c.surface,
      'Surface muted': c.surfaceMuted,
      'Surface sunken': c.surfaceSunken,
      'Border': c.border,
      'Border strong': c.borderStrong,
      'Text': c.text,
      'Text secondary': c.textSecondary,
      'Text tertiary': c.textTertiary,
      'Accent (ink)': c.accent,
      'Accent soft': c.accentSoft,
      'New': c.newSignal,
      'New soft': c.newSignalSoft,
      'Disagree': c.disagree,
      'Disagree soft': c.disagreeSoft,
    };
    final styles = {
      'Display · Newsreader 34': t.display,
      'Title · Newsreader 26': t.title,
      'Headline · Newsreader 20': t.headline,
      'Headline small · Newsreader 17': t.headlineSmall,
      'Reading · Newsreader 18': t.reading,
      'Figure · Newsreader 24, tabular': t.figure,
      'Subhead · Inter 15': t.subhead,
      'Body · Inter 15': t.body,
      'Body small · Inter 14': t.bodySmall,
      'Label · Inter 13': t.label,
      'Caption · Inter 12': t.caption,
    };
    const spaces = {
      'xxs': Space.xxs,
      'xs': Space.xs,
      'sm': Space.sm,
      'md': Space.md,
      'lg': Space.lg,
      'xl': Space.xl,
      'xxl': Space.xxl,
      'xxxl': Space.xxxl,
    };

    return Variants(
      children: {
        'Colours': Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          children: [
            for (final e in swatches.entries)
              SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: Space.xxxl,
                      decoration: BoxDecoration(
                        color: e.value,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: c.border),
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(e.key, style: t.caption),
                  ],
                ),
              ),
          ],
        ),
        'Story art inks': Row(
          children: [
            for (final ink in c.visualInks)
              Container(
                width: Space.xxl,
                height: Space.xxl,
                margin: const EdgeInsets.only(right: Space.sm),
                decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
              ),
          ],
        ),
        'Type scale': Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in styles.entries) ...[
              Text(e.key, style: t.caption.copyWith(color: c.textTertiary)),
              Text(
                e.key.startsWith('Figure') ? '1.2 trillion · 14:02 UTC' : 'One story, many sources — தமிழ் · æøå',
                style: e.value,
              ),
              const SizedBox(height: Space.md),
            ],
          ],
        ),
        'Spacing': Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in spaces.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Row(
                  children: [
                    SizedBox(width: Space.xxxl, child: Text(e.key, style: t.caption)),
                    Container(width: e.value, height: Space.md, color: c.newSignal),
                    const SizedBox(width: Space.sm),
                    Text('${e.value.toInt()} px', style: t.caption.copyWith(color: c.textTertiary)),
                  ],
                ),
              ),
          ],
        ),
      },
    );
  }
}

@widgetbook.UseCase(name: 'Colours, type, spacing', type: DesignTokens, path: '[Foundations]')
Widget designTokens(BuildContext context) => const Frame(maxWidth: 900, child: DesignTokens());
