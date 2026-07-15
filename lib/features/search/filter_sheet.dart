import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/category.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../pro/paywall_page.dart';

/// Alle Filter aus dem Konzept an einem Ort.
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterSheet(),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final f = state.filters;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  const Text(
                    'Filter',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: state.clearFilters,
                    child: const Text('Zurücksetzen'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  const _Label('Kategorie'),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final c in SpotCategory.values)
                        FilterChip(
                          label: Text('${c.emoji} ${c.label}'),
                          selected: f.categories.contains(c),
                          onSelected: (on) {
                            final next = Set<SpotCategory>.of(f.categories);
                            on ? next.add(c) : next.remove(c);
                            state.setFilters(f.copyWith(categories: next));
                          },
                          selectedColor: c.color,
                          checkmarkColor: Colors.white,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  const _Label('Schwierigkeit'),
                  Wrap(
                    spacing: 7,
                    children: [
                      for (final d in Difficulty.values)
                        FilterChip(
                          label: Text(d.label),
                          selected: f.difficulties.contains(d),
                          onSelected: (on) {
                            final next = Set<Difficulty>.of(f.difficulties);
                            on ? next.add(d) : next.remove(d);
                            state.setFilters(f.copyWith(difficulties: next));
                          },
                          selectedColor: d.color,
                          checkmarkColor: Colors.white,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  _Label('Länge der Wanderung'
                      '${f.maxHikeKm != null ? ' — unter ${f.maxHikeKm!.round()} km' : ''}'),
                  Slider(
                    value: f.maxHikeKm ?? 20,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: f.maxHikeKm == null ? 'egal' : '${f.maxHikeKm!.round()} km',
                    onChanged: (v) => state.setFilters(f.copyWith(maxHikeKm: v)),
                  ),
                  if (f.maxHikeKm != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            state.setFilters(f.copyWith(clearMaxHike: true)),
                        child: const Text('Egal', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  const SizedBox(height: 12),

                  const _Label('Ausstattung'),
                  _Switch(
                    emoji: '🐕',
                    label: 'Hunde erlaubt',
                    value: f.dogsAllowed,
                    onChanged: (v) => state.setFilters(f.copyWith(dogsAllowed: v)),
                  ),
                  _Switch(
                    emoji: '👶',
                    label: 'Für Kinder geeignet',
                    value: f.kidsFriendly,
                    onChanged: (v) => state.setFilters(f.copyWith(kidsFriendly: v)),
                  ),
                  _Switch(
                    emoji: '🅿️',
                    label: 'Parkplatz vorhanden',
                    value: f.hasParking,
                    onChanged: (v) => state.setFilters(f.copyWith(hasParking: v)),
                  ),
                  _Switch(
                    emoji: '🏕️',
                    label: 'Camping erlaubt',
                    value: f.campingAllowed,
                    onChanged: (v) => state.setFilters(f.copyWith(campingAllowed: v)),
                  ),
                  const SizedBox(height: 14),

                  const _Label('Zeitpunkt'),
                  _Switch(
                    emoji: '📅',
                    label: 'Nur Spots, die jetzt Saison haben',
                    value: f.onlyInSeason,
                    onChanged: (v) => state.setFilters(f.copyWith(onlyInSeason: v)),
                  ),
                  const SizedBox(height: 14),

                  const _Label('Exklusiv'),
                  _Switch(
                    emoji: '💎',
                    label: 'Nur Hidden Gems',
                    sublabel: 'Hoch bewertet, aber kaum besucht',
                    value: f.onlyHiddenGems,
                    pro: !state.isPro,
                    onChanged: (v) {
                      if (!state.isPro) {
                        Navigator.of(context).pop();
                        PaywallPage.show(context, feature: 'Hidden Gems');
                        return;
                      }
                      state.setFilters(f.copyWith(onlyHiddenGems: v));
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                14 + MediaQuery.of(context).padding.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '${state.visibleSpots.length} Spots anzeigen',
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      );
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.emoji,
    required this.label,
    required this.value,
    required this.onChanged,
    this.sublabel,
    this.pro = false,
  });

  final String emoji;
  final String label;
  final String? sublabel;
  final bool value;
  final bool pro;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: const TextStyle(fontSize: 14)),
                      if (pro) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.proGold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );
}
