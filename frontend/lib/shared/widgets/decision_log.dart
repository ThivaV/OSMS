import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../formatting.dart';
import 'section_header.dart';

/// "How OSMS decided": the model decisions behind a story, oldest first. Loaded when
/// the reader asks to see them; [decisions] shows them at once (Widgetbook, tests).
class DecisionLogSection extends StatefulWidget {
  const DecisionLogSection({super.key, this.decisions, this.load});

  final List<Decision>? decisions;

  /// Null hides the section: the samples have no decisions behind them.
  final Future<List<Decision>> Function()? load;

  @override
  State<DecisionLogSection> createState() => _DecisionLogSectionState();
}

class _DecisionLogSectionState extends State<DecisionLogSection> {
  Future<List<Decision>>? _loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final shown = widget.decisions;
    if (shown == null && widget.load == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(icon: Icons.account_tree_outlined, title: 'How OSMS decided'),
        const SizedBox(height: Space.xs),
        Text(
          'Every model call behind this story: which model decided, what it said, what it changed.',
          style: t.caption.copyWith(color: c.textTertiary),
        ),
        const SizedBox(height: Space.md),
        if (shown != null)
          _DecisionList(decisions: shown)
        else if (_loading == null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _loading = widget.load!()),
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Show the decisions'),
            ),
          )
        else
          FutureBuilder(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'The decisions aren’t available right now.',
                  style: t.caption.copyWith(color: c.textSecondary),
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              return _DecisionList(decisions: snapshot.data!);
            },
          ),
      ],
    );
  }
}

class _DecisionList extends StatelessWidget {
  const _DecisionList({required this.decisions});

  final List<Decision> decisions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    if (decisions.isEmpty) {
      return Text('No model decisions recorded for this story yet.', style: t.caption.copyWith(color: c.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final d in decisions) _DecisionRow(decision: d)],
    );
  }
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.decision});

  final Decision decision;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final d = decision;
    final tokens = d.inputTokens + d.outputTokens;
    final latency = d.latency;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(d.step, style: t.label.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  d.fallback == null ? d.decidedBy : '${d.decidedBy} (backup for ${Decision.modelName(d.model)})',
                  style: t.caption.copyWith(color: c.accent, fontWeight: FontWeight.w600),
                ),
                Text(clockTime(d.at), style: t.caption.copyWith(color: c.textTertiary)),
              ],
            ),
            if (d.about != null) ...[
              const SizedBox(height: Space.xxs),
              Text(
                d.source == null ? d.about! : '${d.about} · ${d.source}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(color: c.textSecondary),
              ),
            ],
            if (d.reason != null) ...[const SizedBox(height: Space.xs), Text('“${d.reason}”', style: t.body)],
            if (d.outcome != null) ...[
              const SizedBox(height: Space.xs),
              Text(d.outcome!, style: t.body.copyWith(fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: Space.xxs),
            Text(
              [
                if (tokens > 0) '$tokens tokens',
                if (latency != null) '${(latency.inMilliseconds / 1000).toStringAsFixed(1)} s',
              ].join(' · '),
              style: t.caption.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
