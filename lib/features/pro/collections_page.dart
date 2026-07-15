import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/category.dart';
import '../../core/models/spot.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/spot_photo.dart';
import '../search/search_page.dart';
import 'paywall_page.dart';

/// Kuratierte Sammlungen — im Konzept ein PRO-Feature.
///
/// Eine Collection ist eine benannte Regel über den Spots, keine handgepflegte
/// Liste. Dadurch wächst sie automatisch mit, wenn Nutzer neue Spots posten.
class Collection {
  const Collection({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.filter,
    required this.sort,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final bool Function(Spot) filter;
  final int Function(Spot, Spot) sort;

  List<Spot> resolve(List<Spot> all) {
    final list = all.where(filter).toList()..sort(sort);
    return list;
  }

  static int byRating(Spot a, Spot b) => b.rating.compareTo(a.rating);
  static int byLikes(Spot a, Spot b) => b.likes.compareTo(a.likes);
  static int byQuiet(Spot a, Spot b) => a.visitorsPerDay.compareTo(b.visitorsPerDay);

  static const europe = {
    'Italien', 'Norwegen', 'Kroatien', 'Island', 'Österreich', 'Deutschland',
    'Frankreich', 'Schweiz', 'Irland', 'Griechenland', 'Tschechien',
    'Schottland', 'Portugal', 'Schweden', 'Niederlande',
  };

  static List<Collection> all() => [
        Collection(
          title: 'Die schönsten Wasserfälle Europas',
          subtitle: 'Von Island bis Kroatien',
          emoji: '🌊',
          filter: (s) =>
              s.category == SpotCategory.waterfall && europe.contains(s.country),
          sort: byRating,
        ),
        Collection(
          title: 'Top Sonnenaufgänge',
          subtitle: 'Wenn es sich lohnt, im Dunkeln loszugehen',
          emoji: '🌅',
          filter: (s) => s.category == SpotCategory.sunrise,
          sort: byRating,
        ),
        Collection(
          title: 'Beste Lavendel- & Blumenfelder',
          subtitle: 'Kurze Blüte, großer Effekt',
          emoji: '🌸',
          filter: (s) => s.category == SpotCategory.flowers,
          sort: byLikes,
        ),
        Collection(
          title: 'Herbstspots',
          subtitle: 'Wenn der Wald brennt',
          emoji: '🍂',
          filter: (s) => s.category == SpotCategory.autumn,
          sort: byRating,
        ),
        Collection(
          title: 'Dunkelster Nachthimmel',
          subtitle: 'Milchstraße, Polarlicht, keine Lichter',
          emoji: '🌌',
          filter: (s) => s.category == SpotCategory.nightSky,
          sort: byQuiet,
        ),
        Collection(
          title: 'Ohne Anstrengung',
          subtitle: 'Große Bilder, kurzer Weg — unter 30 Minuten',
          emoji: '🅿️',
          filter: (s) => s.hikeMinutes <= 30 && s.hasParking,
          sort: byRating,
        ),
        Collection(
          title: 'Nur für Erfahrene',
          subtitle: 'Lange Wege, echte Höhenmeter',
          emoji: '⛰️',
          filter: (s) => s.difficulty == Difficulty.hard || s.hikeKm >= 8,
          sort: byRating,
        ),
        Collection(
          title: 'Mit Hund',
          subtitle: 'Hunde erlaubt, Parkplatz vorhanden',
          emoji: '🐕',
          filter: (s) => s.dogsAllowed && s.hasParking,
          sort: byRating,
        ),
      ];
}

class CollectionsPage extends StatelessWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final collections = Collection.all();

    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: collections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final c = collections[i];
          final spots = c.resolve(state.allSpots);

          return GestureDetector(
            onTap: () {
              if (!state.isPro) {
                PaywallPage.show(context, feature: 'Collections');
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _CollectionDetailPage(collection: c),
                ),
              );
            },
            child: Container(
              height: 128,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (spots.isNotEmpty) SpotPhoto(spot: spots.first),
                  const PhotoScrim(opacity: 0.85),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Text(c.emoji, style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (!state.isPro)
                              const Icon(Icons.lock, size: 16, color: AppTheme.proGold),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${c.subtitle} · ${spots.length} Spots',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CollectionDetailPage extends StatelessWidget {
  const _CollectionDetailPage({required this.collection});

  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final spots = collection.resolve(context.watch<AppState>().allSpots);

    return Scaffold(
      appBar: AppBar(title: Text('${collection.emoji} ${collection.title}')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: spots.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => SpotListTile(
          spot: spots[i],
          trailing: Text(
            '#${i + 1}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
