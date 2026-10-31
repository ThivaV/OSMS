import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import 'interests_editor.dart';

/// Edit the reader's research interest on arXiv (the first one, for now).
class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  static const _settle = Duration(milliseconds: 800);
  bool _saving = false;

  /// The interest agent's suggestions for the keywords on screen. Flags accumulate:
  /// the editor leaves flagged keywords out of its draft, so they must stay flagged.
  List<String> _suggested = const [];
  final Set<String> _flagged = {};
  Set<String> _asked = const {};
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(InterestDraft draft) {
    final words = {...draft.keywords, ..._flagged};
    if (words.isEmpty || setEquals(words, _asked)) return;
    _debounce?.cancel();
    _debounce = Timer(_settle, () async {
      _asked = words;
      try {
        final help = await ref.read(apiClientProvider).suggestInterest(words.toList());
        if (!mounted || !setEquals(words, _asked)) return;
        setState(() {
          _suggested = help.relatedTerms;
          _flagged.addAll(help.flagged);
        });
      } on ApiException {
        // Suggestions are a help, not a step: without them the editor works as before.
      }
    });
  }

  Future<void> _save(InterestDraft draft) async {
    setState(() => _saving = true);
    try {
      await ref.read(sessionProvider.notifier).saveInterest(draft);
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final interest = ref.watch(sessionProvider).requireValue.account?.interests.firstOrNull;
    if (_asked.isEmpty && (interest?.keywords.isNotEmpty ?? false)) {
      // Help with the saved keywords too, not only after an edit.
      _changed(InterestDraft(keywords: interest!.keywords));
    }
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: Center(
            child: AbsorbPointer(
              absorbing: _saving,
              child: InterestsEditor(
                initialKeywords: interest?.keywords ?? const [],
                initialRelated: {...?interest?.relatedTerms},
                initialCategories: {...?interest?.categories},
                suggestedTerms: _suggested,
                flagged: _flagged,
                onChanged: _changed,
                onSave: _save,
                onClose: () => context.go('/'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
