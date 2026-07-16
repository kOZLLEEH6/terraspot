import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/spot.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/spot_photo.dart';
import '../pro/paywall_page.dart';
import '../spot/spot_detail_page.dart';

/// Feed mit den vier Tabs aus dem Konzept.
/// Im Free-Tier steht zwischen den Beiträgen Werbung — Hidden Gems sind gesperrt.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.moderatedSpots;

    final today = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final trending = [...all]..sort((a, b) => b.likes.compareTo(a.likes));

    // "In deiner Nähe": nach echter Entfernung, sobald der Standort bekannt ist —
    // sonst als Fallback nach kürzester Wanderung (leicht erreichbar).
    final here = state.userLocation;
    final nearby = [...all];
    if (here != null) {
      const d = Distance();
      nearby.sort((a, b) => d
          .as(LengthUnit.Kilometer, here, a.position)
          .compareTo(d.as(LengthUnit.Kilometer, here, b.position)));
    } else {
      nearby.sort((a, b) => a.hikeMinutes.compareTo(b.hikeMinutes));
    }
    final gems = all.where((s) => s.isHiddenGem).toList()
      ..sort((a, b) => a.visitorsPerDay.compareTo(b.visitorsPerDay));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Heute neu'),
            Tab(text: 'Trending'),
            Tab(text: 'Hidden Gems'),
            Tab(text: 'In deiner Nähe'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FeedList(spots: today.take(12).toList()),
          _FeedList(spots: trending.take(12).toList()),
          state.isPro
              ? _FeedList(spots: gems, emptyHint: 'Keine Hidden Gems gefunden.')
              : const _GemsLocked(),
          _FeedList(spots: nearby.take(12).toList()),
        ],
      ),
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({required this.spots, this.emptyHint});

  final List<Spot> spots;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<AppState>().isPro;

    if (spots.isEmpty) {
      return Center(
        child: Text(
          emptyHint ?? 'Nichts hier.',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    // Free: nach jedem vierten Beitrag eine Anzeige (aus dem Erlösmodell).
    final items = <Widget>[];
    for (var i = 0; i < spots.length; i++) {
      items.add(_FeedCard(spot: spots[i]));
      if (!isPro && (i + 1) % 4 == 0 && i != spots.length - 1) {
        items.add(const _AdSlot());
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: items,
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final liked = state.isLiked(spot.id);
    final saved = state.isSaved(spot.id);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SpotDetailPage(spotId: spot.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SpotPhoto(spot: spot),
                  const PhotoScrim(opacity: 0.7),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: spot.category.color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${spot.category.emoji} ${spot.category.label}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${spot.region}, ${spot.country}',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
              child: Row(
                children: [
                  _Action(
                    icon: liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? const Color(0xFFFF4D6D) : AppTheme.textMuted,
                    label: '${spot.likes}',
                    onTap: () => state.toggleLike(spot.id),
                  ),
                  _Action(
                    icon: Icons.mode_comment_outlined,
                    color: AppTheme.textMuted,
                    label: '${spot.ratingCount ~/ 10}',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kommentare kommen im nächsten Schritt')),
                    ),
                  ),
                  _Action(
                    icon: Icons.ios_share,
                    color: AppTheme.textMuted,
                    label: '',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${spot.title} geteilt')),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () async {
                      final ok = await state.toggleSaved(spot.id);
                      if (!ok && context.mounted) {
                        PaywallPage.show(
                          context,
                          feature: 'Mehr als ${AppState.freeSaveLimit} gespeicherte Orte',
                        );
                      }
                    },
                    icon: Icon(
                      saved ? Icons.bookmark : Icons.bookmark_border,
                      color: saved ? AppTheme.accent : AppTheme.textMuted,
                      size: 21,
                    ),
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

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19, color: color),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
        ),
      );
}

/// Werbung im Free-Tier — bewusst nur im Feed, nie auf der Karte.
class _AdSlot extends StatelessWidget {
  const _AdSlot();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Text('🎒', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Outdoor-Ausrüstung',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'ANZEIGE',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Anzeigen-Platzhalter. PRO entfernt sie.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => PaywallPage.show(context, feature: 'Werbefreiheit'),
              child: const Text('Entfernen', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
}

class _GemsLocked extends StatelessWidget {
  const _GemsLocked();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💎', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'Hidden Gems sind PRO',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hoch bewertete Spots, an denen kaum jemand steht. '
                'Genau die, die man nicht auf Instagram findet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => PaywallPage.show(context, feature: 'Hidden Gems'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.proGold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('PRO freischalten'),
              ),
            ],
          ),
        ),
      );
}
