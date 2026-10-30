import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens.dart';
import '../../shared/widgets/keycap.dart';

class CommandItem {
  const CommandItem({
    required this.icon,
    required this.label,
    required this.group,
    this.detail,
    this.shortcut,
    this.leading,
    this.onRun,
  });

  final IconData icon;
  final String label;

  /// Heading it sits under: "Stories", "Sources", "Actions".
  final String group;
  final String? detail;
  final String? shortcut;

  /// Replaces the icon, e.g. a source avatar.
  final Widget? leading;
  final VoidCallback? onRun;
}

/// ⌘K / Ctrl+K: one box for every story, source and action. Arrow keys move,
/// Enter opens, Esc closes.
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.items, this.initialQuery = '', this.onClose});

  final List<CommandItem> items;
  final String initialQuery;
  final VoidCallback? onClose;

  static const _width = 640.0;
  static const _listHeight = 420.0;

  /// Opens the palette as a dialog near the top of the window.
  static Future<void> show(BuildContext context, List<CommandItem> items) => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (dialogContext) => Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(Space.lg, Space.xxxl * 2, Space.lg, Space.lg),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: CommandPalette(items: items, onClose: () => Navigator.pop(dialogContext)),
    ),
  );

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  int _highlight = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<CommandItem> get _matches {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((i) => i.label.toLowerCase().contains(q) || (i.detail?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  void _run(CommandItem item) {
    widget.onClose?.call();
    item.onRun?.call();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, List<CommandItem> matches, int highlight) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown && matches.isNotEmpty) {
      setState(() => _highlight = (highlight + 1) % matches.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && matches.isNotEmpty) {
      setState(() => _highlight = (highlight - 1 + matches.length) % matches.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && matches.isNotEmpty) {
      _run(matches[highlight]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final matches = _matches;
    // The list shrinks as the query grows; keep the highlight on a real row.
    final highlight = matches.isEmpty ? 0 : _highlight.clamp(0, matches.length - 1);
    final groups = <String, List<(int, CommandItem)>>{};
    for (final (i, item) in matches.indexed) {
      groups.putIfAbsent(item.group, () => []).add((i, item));
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: CommandPalette._width),
      child: Material(
        color: c.surface,
        elevation: Space.lg,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
          side: BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Focus(
              onKeyEvent: (node, event) => _onKey(node, event, matches, highlight),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: t.body,
                onChanged: (_) => setState(() => _highlight = 0),
                decoration: InputDecoration(
                  hintText: 'Search stories, sources and actions',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: const Padding(
                    padding: EdgeInsets.all(Space.md),
                    child: Keycap('esc'),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.all(Space.lg),
                ),
              ),
            ),
            const Divider(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: CommandPalette._listHeight),
              child: matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Text(
                        'Nothing matches “${_controller.text}”.',
                        textAlign: TextAlign.center,
                        style: t.body.copyWith(color: c.textSecondary),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(Space.sm),
                      children: [
                        for (final MapEntry(key: group, value: rows) in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, Space.xs),
                            child: Text(
                              group,
                              style: t.caption.copyWith(color: c.textTertiary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          for (final (i, item) in rows)
                            _Row(
                              item: item,
                              highlighted: i == highlight,
                              onTap: () => _run(item),
                              onHover: () => setState(() => _highlight = i),
                            ),
                        ],
                      ],
                    ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
              child: Wrap(
                spacing: Space.lg,
                runSpacing: Space.xs,
                children: [
                  for (final (keys, label) in const [('↑ ↓', 'move'), ('↵', 'open'), ('esc', 'close')])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Keycap(keys),
                        const SizedBox(width: Space.xs),
                        Text(label, style: t.caption.copyWith(color: c.textTertiary)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.item, required this.highlighted, required this.onTap, required this.onHover});

  final CommandItem item;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  @override
  void didUpdateWidget(covariant _Row old) {
    super.didUpdateWidget(old);
    // Keyboard travel keeps the row on screen; after layout, never during it.
    if (widget.highlighted && !old.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Scrollable.ensureVisible(context, alignment: 0.5);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final item = widget.item;
    return Semantics(
      button: true,
      selected: widget.highlighted,
      child: Material(
        color: widget.highlighted ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: widget.onTap,
          onHover: (_) => widget.onHover(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
            child: Row(
              children: [
                SizedBox(
                  width: Sizes.avatarMd,
                  child: Center(child: item.leading ?? Icon(item.icon, size: Sizes.iconMd, color: c.textSecondary)),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: item.label, style: t.body.copyWith(color: c.text)),
                        if (item.detail != null) TextSpan(text: '  ${item.detail}'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: c.textTertiary),
                  ),
                ),
                if (item.shortcut != null) ...[const SizedBox(width: Space.sm), Keycap(item.shortcut!)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
