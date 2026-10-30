import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

const _languageNames = {'da': 'Danish', 'en': 'English', 'ta': 'Tamil'};

/// A source's own words, exactly as it wrote them, in its language. In a story written
/// in another language the translation follows, labelled "Translated by OSMS", so the
/// reader can always check the original wording.
class SourceQuote extends StatelessWidget {
  const SourceQuote({
    super.key,
    required this.quote,
    required this.language,
    this.translation,
    this.readerLanguage = 'en',
  });

  final String quote;

  /// ISO 639-1 code of [quote]: `da`, `en`, `ta`, ...
  final String language;
  final String? translation;

  /// The story's language; a quote in it needs no translation.
  final String readerLanguage;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final translated = translation != null && translation!.trim().isNotEmpty && language != readerLanguage;
    return Container(
      padding: const EdgeInsets.only(left: Space.md),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: c.border, width: Sizes.rail),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“$quote”',
            style: t.bodySmall.copyWith(fontStyle: FontStyle.italic, color: c.text),
          ),
          if (language != readerLanguage) ...[
            const SizedBox(height: Space.xxs),
            Text(
              'In ${_languageNames[language] ?? language.toUpperCase()}',
              style: t.caption.copyWith(color: c.textTertiary),
            ),
          ],
          if (translated) ...[
            const SizedBox(height: Space.sm),
            Text(
              'TRANSLATED BY OSMS',
              style: t.caption.copyWith(color: c.textTertiary, fontWeight: FontWeight.w600, letterSpacing: 0.6),
            ),
            const SizedBox(height: Space.xxs),
            Text('“${translation!.trim()}”', style: t.bodySmall.copyWith(color: c.textSecondary)),
          ],
        ],
      ),
    );
  }
}
