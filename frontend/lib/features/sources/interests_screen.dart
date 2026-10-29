import 'package:flutter/material.dart';
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
  bool _saving = false;

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
