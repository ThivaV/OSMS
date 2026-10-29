import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/auth_client.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import 'sign_in_page.dart';

/// Sign in and create an account, on one page. Google in every build; an emailed
/// link only in local development, where the link is printed in the auth log.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.createAccount = false});

  final bool createAccount;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  SignInProvider? _pending;

  SessionController get _session => ref.read(sessionProvider.notifier);

  Future<void> _continue(SignInProvider provider) async {
    _session.clearMessage();
    // The email link asks in a dialog; only Google has a window to wait for.
    if (provider == SignInProvider.emailLink) return _emailLink();
    setState(() => _pending = provider);
    try {
      await _session.signInWithGoogle();
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _emailLink() async {
    final email = await showDialog<String>(context: context, builder: (_) => const _EmailLinkDialog());
    if (email == null || !mounted) return;
    try {
      await _session.sendEmailLink(email);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open the link in the sign-in log'),
        content: const Text(
          'In development nothing is emailed. The link is printed in the sign-in service’s log '
          '(the auth resource in Tilt, or the terminal running make auth). It works once, for 5 minutes.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).requireValue;
    final providers = [
      if (session.providers.google) SignInProvider.google,
      if (session.providers.emailLink) SignInProvider.emailLink,
    ];
    final status = !session.available || providers.isEmpty
        ? SignInStatus.unavailable
        : _pending != null
        ? SignInStatus.signingIn
        : session.message != null
        ? SignInStatus.error
        : SignInStatus.idle;
    return SignInPage(
      providers: providers.isEmpty ? const [SignInProvider.google] : providers,
      status: status,
      pending: _pending,
      error: session.message,
      initialIntent: widget.createAccount ? SignInIntent.createAccount : SignInIntent.signIn,
      onContinue: _continue,
      onTryDemo: () => context.go('/'),
      onWhatWeKeep: () => context.go('/what-we-keep'),
    );
  }
}

class _EmailLinkDialog extends StatefulWidget {
  const _EmailLinkDialog();

  @override
  State<_EmailLinkDialog> createState() => _EmailLinkDialogState();
}

class _EmailLinkDialogState extends State<_EmailLinkDialog> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    final email = _email.text.trim();
    if (email.contains('@')) Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in with an email link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email address'),
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Local development only. The link appears in the sign-in log instead of your inbox.',
            style: context.text.caption.copyWith(color: context.colors.textTertiary),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _send, child: const Text('Send link')),
      ],
    );
  }
}
