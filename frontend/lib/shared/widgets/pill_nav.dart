import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import 'glass.dart';

class PillNavDestination {
  const PillNavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The phone tab bar: a glass capsule floating 16 px above the bottom edge.
/// The selected tab gets a filled pill and bold label, never colour alone.
class PillNav extends StatelessWidget {
  const PillNav({super.key, required this.destinations, required this.selected, required this.onSelect});

  final List<PillNavDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelect;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return GlassSurface(
      padding: const EdgeInsets.all(Space.xs + Space.xxs),
      child: SizedBox(
        height: height - (Space.xs + Space.xxs) * 2,
        child: Row(
          children: [
            for (final (i, d) in destinations.indexed)
              Expanded(
                child: Semantics(
                  selected: i == selected,
                  button: true,
                  label: d.label,
                  excludeSemantics: true,
                  child: Material(
                    color: i == selected ? c.accentSoft : Colors.transparent,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onSelect(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(d.icon, size: Sizes.iconMd, color: i == selected ? c.text : c.textSecondary),
                          const SizedBox(height: Space.xxs),
                          Text(
                            d.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(
                              color: i == selected ? c.text : c.textSecondary,
                              fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
