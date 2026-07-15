import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/category.dart';
import '../../core/models/filters.dart';
import '../../core/models/spot.dart';
import '../../core/services/nl_search_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/spot_photo.dart';
import '../pro/collections_page.dart';
import '../pro/paywall_page.dart';
import '../spot/spot_detail_page.dart';
import 'filter_sheet.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<String> _understood = [];
  bool _smartMode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String input) async {
    final state = context.read<AppState>();

    if (_smartMode) {
      var result = NlSearchService.parse(input, state.filters);

      // Umkreissuche ("in meiner Nähe", "innerhalb 50 km") braucht ein Zentrum.
      // Fehlt der Standort noch, holen wir ihn jetzt per GPS und ergänzen ihn.
      if (result.filters.maxDistanceKm != null && state.userLocation == null) {
        final loc = await state.locateUser();
        if (loc.isSuccess) {
          result = NlSearchService.parse(input, state.filters);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.message ?? 'Standort nicht verfügbar')),
          );
        }
      }

      state.setFilters(result.filters);
      if (mounted) setState(() => _understood = result.understood);
    } else {
      state.setFilters(state.filters.copyWith(query: input));
      setState(() => _understood = []);
    }
  }

  void _toggleSmart() {
    final state = context.read<AppState>();
    if (!state.isPro) {
      PaywallPage.show(context, feature: 'Die intelligente Suche');
      return;
    }
    setState(() => _smartMode = !_smartMode);
    if (_controller.text.isNotEmpty) _runSearch(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final results = state.visibleSpots;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suchen'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: () => FilterSheet.show(context),
            icon: Badge(
              isLabelVisible: state.filters.activeCount > 0,
              label: Text('${state.filters.activeCount}'),
              backgroundColor: AppTheme.accent,
              textColor: Colors.black,
              child: const Icon(Icons.tune),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          TextField(
            controller: _controller,
            onSubmitted: _runSearch,
            onChanged: (v) {
              if (!_smartMode) _runSearch(v);
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: _smartMode
                  ? 'z. B. leichte Wanderung mit Wasserfall unter 5 km, Hunde erlaubt'
                  : 'Land, Region, Berg, See ...',
              prefixIcon: Icon(
                _smartMode ? Icons.auto_awesome : Icons.search,
                color: _smartMode ? AppTheme.proGold : AppTheme.textMuted,
              ),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _controller.clear();
                        context.read<AppState>().clearFilters();
                        setState(() => _understood = []);
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Umschalter: normale Suche <-> intelligente Suche (PRO)
          GestureDetector(
            onTap: _toggleSmart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _smartMode
                    ? AppTheme.proGold.withValues(alpha: 0.14)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _smartMode
                      ? AppTheme.proGold.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: _smartMode ? AppTheme.proGold : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _smartMode
                          ? 'Intelligente Suche aktiv — beschreib einfach, was du suchst'
                          : 'Intelligente Suche einschalten',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _smartMode ? AppTheme.proGold : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  if (!state.isPro)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.proGold,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    )
                  else
                    Switch(
                      value: _smartMode,
                      onChanged: (_) => _toggleSmart(),
                      activeThumbColor: AppTheme.proGold,
                    ),
                ],
              ),
            ),
          ),

          // Was die Suche verstanden hat — nachvollziehbar statt magisch.
          if (_understood.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Verstanden als',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in _understood)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.proGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      u,
                      style: const TextStyle(fontSize: 12, color: AppTheme.proGold),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 18),

          if (state.filters.isEmpty) ...[
            _QuickFilters(onPick: (f) {
              context.read<AppState>().setFilters(f);
            }),
            const SizedBox(height: 22),
            _CollectionsTeaser(),
            const SizedBox(height: 22),
            const Text(
              'Beliebte Länder',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _CountryGrid(spots: state.allSpots),
          ] else ...[
            Row(
              children: [
                Text(
                  '${results.length} ${results.length == 1 ? 'Ergebnis' : 'Ergebnisse'}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _controller.clear();
                    context.read<AppState>().clearFilters();
                    setState(() => _understood = []);
                  },
                  icon: const Icon(Icons.close, size: 15),
                  label: const Text('Zurücksetzen'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Column(
                  children: [
                    Text('🗺️', style: TextStyle(fontSize: 40)),
                    SizedBox(height: 12),
                    Text(
                      'Kein Spot passt auf diese Filter.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              )
            else
              for (final s in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SpotListTile(spot: s),
                ),
          ],
        ],
      ),
    );
  }
}

/// Die Schnellfilter aus dem Konzept.
class _QuickFilters extends StatelessWidget {
  const _QuickFilters({required this.onPick});

  final ValueChanged<SpotFilters> onPick;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, SpotFilters)>[
      ('🌅', 'Nur Sonnenaufgänge',
          const SpotFilters(categories: {SpotCategory.sunrise})),
      ('🌊', 'Nur Wasserfälle',
          const SpotFilters(categories: {SpotCategory.waterfall})),
      ('🌌', 'Nur Nachtfotografie',
          const SpotFilters(categories: {SpotCategory.nightSky})),
      ('🥾', 'Nur leichte Wanderungen',
          const SpotFilters(difficulties: {Difficulty.easy})),
      ('❄️', 'Nur Winter', const SpotFilters(categories: {SpotCategory.winter})),
      ('📅', 'Jetzt in Saison', const SpotFilters(onlyInSeason: true)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schnellfilter',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (emoji, label, filters) in items)
              GestureDetector(
                onTap: () => onPick(filters),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CollectionsTeaser extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CollectionsPage()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                AppTheme.accentAlt.withValues(alpha: 0.2),
                AppTheme.surface,
              ],
            ),
            border: Border.all(color: AppTheme.accentAlt.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collections',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '100 schönste Wasserfälle, Top 50 Sonnenaufgänge, Herbstspots ...',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      );
}

class _CountryGrid extends StatelessWidget {
  const _CountryGrid({required this.spots});

  final List<Spot> spots;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final s in spots) {
      counts[s.country] = (counts[s.country] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in sorted.take(12))
          GestureDetector(
            onTap: () => context
                .read<AppState>()
                .setFilters(SpotFilters(query: e.key)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${e.value}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Listeneintrag für einen Spot — wird von Suche, Feed, Profil und Collections geteilt.
class SpotListTile extends StatelessWidget {
  const SpotListTile({super.key, required this.spot, this.trailing});

  final Spot spot;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SpotDetailPage(spotId: spot.id)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(width: 96, height: 96, child: SpotPhoto(spot: spot)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(spot.category.emoji, style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(
                          spot.category.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w800,
                            color: spot.category.color,
                          ),
                        ),
                        if (state.isPro && spot.isHiddenGem) ...[
                          const SizedBox(width: 6),
                          const Text('💎', style: TextStyle(fontSize: 10)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${spot.region}, ${spot.country}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppTheme.proGold),
                        const SizedBox(width: 2),
                        Text(
                          spot.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.terrain, size: 13, color: spot.difficulty.color),
                        const SizedBox(width: 3),
                        Text(
                          spot.difficulty.label,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.schedule, size: 13, color: AppTheme.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          spot.hikeLabel,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (trailing != null) Padding(
              padding: const EdgeInsets.only(right: 10),
              child: trailing!,
            ),
          ],
        ),
      ),
    );
  }
}
