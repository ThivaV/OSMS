import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/appearance.dart';
import '../../core/theme/palettes.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/source_chip.dart';
import '../../shared/widgets/story_card.dart';
import 'theme_picker.dart';

/// Appearance, reading and account. Every change applies straight away.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.appearance,
    required this.onAppearanceChanged,
    required this.languages,
    this.language = 'en',
    this.onLanguageChanged,
    this.defaultLayout = StoryCardLayout.row,
    this.onDefaultLayoutChanged,
    this.user,
    this.previewStory,
    this.onBack,
    this.onWhatWeKeep,
    this.onSignOut,
    this.onDeleteAccount,
  });

  final Appearance appearance;
  final ValueChanged<Appearance> onAppearanceChanged;
  final List<AppLanguage> languages;
  final String language;
  final ValueChanged<String>? onLanguageChanged;
  final StoryCardLayout defaultLayout;
  final ValueChanged<StoryCardLayout>? onDefaultLayoutChanged;

  /// Null while signed out: the account section then offers sign-in only.
  final User? user;

  /// Shown under Appearance so changes can be judged on a real card.
  final Story? previewStory;
  final VoidCallback? onBack;
  final VoidCallback? onWhatWeKeep;
  final VoidCallback? onSignOut;
  final VoidCallback? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final brightness = Theme.of(context).brightness;
    void set(Appearance a) => onAppearanceChanged(a);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: onBack == null
            ? null
            : IconButton(tooltip: 'Back', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.readingWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  title: 'Appearance',
                  children: [
                    _Field(
                      label: 'Mode',
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                        ],
                        selected: {appearance.mode},
                        onSelectionChanged: (s) => set(appearance.copyWith(mode: s.first)),
                      ),
                    ),
                    _Field(
                      label: 'Theme',
                      child: ThemePicker(
                        palettes: Palettes.all,
                        selectedId: appearance.paletteId,
                        brightness: brightness,
                        onSelect: (p) => set(appearance.copyWith(paletteId: p.id)),
                      ),
                    ),
                    _SwitchRow(
                      title: 'Pure black',
                      subtitle: brightness == Brightness.dark
                          ? 'Pure black backgrounds, kinder to OLED screens.'
                          : 'Pure black backgrounds in dark mode, for OLED screens.',
                      value: appearance.pureBlack,
                      onChanged: (v) => set(appearance.copyWith(pureBlack: v)),
                    ),
                    _Field(
                      label: 'Floating bars',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SegmentedButton<GlassStyle>(
                            showSelectedIcon: false,
                            segments: [
                              for (final g in GlassStyle.values) ButtonSegment(value: g, label: Text(g.label)),
                            ],
                            selected: {appearance.glass},
                            onSelectionChanged: appearance.paletteId == Palettes.contrast.id
                                ? null
                                : (s) => set(appearance.copyWith(glass: s.first)),
                          ),
                          const SizedBox(height: Space.sm),
                          Text(
                            appearance.paletteId == Palettes.contrast.id
                                ? 'Always solid in High contrast.'
                                : 'How see-through the player, toolbar and tab bar are. Reading text is never see-through.',
                            style: t.caption.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    _Field(
                      label: 'Reading font',
                      child: SegmentedButton<ReadingFont>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: ReadingFont.serif,
                            label: Text('Serif', style: t.body.copyWith(fontFamily: Fonts.serif, fontFamilyFallback: Fonts.serifFallback)),
                          ),
                          ButtonSegment(value: ReadingFont.sans, label: Text('Sans', style: t.body)),
                        ],
                        selected: {appearance.readingFont},
                        onSelectionChanged: (s) => set(appearance.copyWith(readingFont: s.first)),
                      ),
                    ),
                    _Field(
                      label: 'Reading text size',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text('A', style: t.label.copyWith(color: c.textSecondary)),
                              Expanded(
                                child: Slider(
                                  min: Appearance.minReadingScale,
                                  max: Appearance.maxReadingScale,
                                  divisions: 11,
                                  value: appearance.readingScale,
                                  label: '${(appearance.readingScale * 100).round()}%',
                                  onChanged: (v) => set(appearance.copyWith(readingScale: v)),
                                ),
                              ),
                              Text('A', style: t.headline.copyWith(color: c.textSecondary)),
                            ],
                          ),
                          Text(
                            'Sixty items become seven stories. This is how summaries and articles will read.',
                            style: t.reading,
                          ),
                        ],
                      ),
                    ),
                    if (previewStory != null)
                      _Field(
                        label: 'Preview',
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(Radii.lg),
                            border: Border.all(color: c.border),
                          ),
                          padding: const EdgeInsets.all(Space.xs),
                          child: StoryCard(story: previewStory!, layout: StoryCardLayout.row, selected: true),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.xl),
                _Section(
                  title: 'Reading',
                  children: [
                    _Field(
                      label: 'OSMS writes in',
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [
                          for (final l in languages) ButtonSegment(value: l.code, label: Text(l.nativeName)),
                        ],
                        selected: {language},
                        onSelectionChanged: onLanguageChanged == null ? null : (s) => onLanguageChanged!(s.first),
                      ),
                    ),
                    _Field(
                      label: 'Stories open as',
                      child: SegmentedButton<StoryCardLayout>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: StoryCardLayout.row, icon: Icon(Icons.view_list_rounded), label: Text('List')),
                          ButtonSegment(value: StoryCardLayout.card, icon: Icon(Icons.view_agenda_outlined), label: Text('Cards')),
                        ],
                        selected: {defaultLayout},
                        onSelectionChanged:
                            onDefaultLayoutChanged == null ? null : (s) => onDefaultLayoutChanged!(s.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xl),
                _Section(
                  title: 'Account',
                  children: [
                    if (user != null)
                      Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Row(
                          children: [
                            MonogramAvatar(id: user!.id, name: user!.displayName, size: Sizes.avatarLg),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user!.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.subhead),
                                  Text(
                                    'Signed in with Google · ${user!.email}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.caption.copyWith(color: c.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    _LinkRow(icon: Icons.shield_outlined, title: 'What OSMS keeps', onTap: onWhatWeKeep),
                    if (user != null) ...[
                      _LinkRow(icon: Icons.logout_rounded, title: 'Sign out', onTap: onSignOut),
                      _LinkRow(
                        icon: Icons.delete_outline_rounded,
                        title: 'Delete my account',
                        destructive: true,
                        onTap: () => _confirmDelete(context),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Space.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This removes your account, the sources you follow, what you have read and saved, and your '
          'briefings. Public stories and sources stay. This can’t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.error, foregroundColor: c.surface),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDeleteAccount?.call();
  }
}

/// A titled, inset group of rows.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Space.xs, bottom: Space.sm),
          child: Semantics(header: true, child: Text(title, style: context.text.subhead)),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.xl),
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[if (i > 0) const Divider(), child],
            ],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.label.copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: Space.md),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.body.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: Space.xxs),
                    Text(subtitle, style: t.caption.copyWith(color: context.colors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.title, this.onTap, this.destructive = false});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = destructive ? c.error : c.text;
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md + Space.xxs),
        child: Row(
          children: [
            Icon(icon, size: Sizes.iconMd, color: destructive ? c.error : c.textSecondary),
            const SizedBox(width: Space.md),
            Expanded(child: Text(title, style: context.text.body.copyWith(color: color))),
            if (!destructive) Icon(Icons.chevron_right_rounded, size: Sizes.iconMd, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}
