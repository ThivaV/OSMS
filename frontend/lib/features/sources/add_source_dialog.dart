import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import 'add_source_sheet.dart';

/// Add a source, for a signed-in reader: OSMS looks up the link or handle, shows what
/// it found, and follows it on Subscribe. Its first stories arrive with the next fetch.
class AddSourceDialog extends ConsumerStatefulWidget {
  const AddSourceDialog({super.key, required this.onClose});

  final VoidCallback onClose;

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(Space.lg),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SingleChildScrollView(child: AddSourceDialog(onClose: () => Navigator.pop(dialogContext))),
    ),
  );

  @override
  ConsumerState<AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends ConsumerState<AddSourceDialog> {
  var _status = AddSourceStatus.idle;
  var _query = '';
  DiscoveredSource? _found;
  String? _message;
  var _subscribing = false;

  Future<void> _find(String query) async {
    setState(() {
      _status = AddSourceStatus.searching;
      _query = query;
      _found = null;
      _message = null;
    });
    try {
      final found = await ref.read(apiClientProvider).discoverSource(query);
      if (!mounted || _query != query) return;
      setState(() {
        _status = AddSourceStatus.found;
        _found = found;
      });
    } on ApiException catch (e) {
      if (!mounted || _query != query) return;
      setState(() {
        _status = e.status == 404 ? AddSourceStatus.notFound : AddSourceStatus.idle;
        _message = switch (e.status) {
          404 => null,
          422 => 'That isn’t an address OSMS can follow. Check it, or paste the site’s home page.',
          _ => e.message,
        };
      });
    }
  }

  Future<void> _subscribe() async {
    final found = _found;
    if (found == null) return;
    setState(() => _subscribing = true);
    try {
      await ref.read(sessionProvider.notifier).followSource(_query);
      if (!mounted) return;
      // The dialog is going: tell the screen behind it.
      final messenger = ScaffoldMessenger.maybeOf(context);
      widget.onClose();
      messenger?.showSnackBar(
        SnackBar(content: Text('Following ${found.source.name}. Its stories arrive with the next fetch.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _subscribing = false;
        _message = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AddSourceSheet(
    status: _status,
    query: _query,
    found: _found,
    message: _message,
    subscribing: _subscribing,
    onClose: widget.onClose,
    onFind: _find,
    onSubscribe: _subscribe,
    onFollowResearch: () {
      final router = GoRouter.of(context);
      widget.onClose();
      router.go('/interests');
    },
  );
}
