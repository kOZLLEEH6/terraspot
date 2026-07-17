import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/category.dart';
import '../../core/models/spot.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/photo_gallery.dart';
import '../../widgets/spot_photo.dart' show PhotoScrim;
import '../pro/paywall_page.dart';
import '../pro/spot_intelligence_panel.dart';
import 'spot_actions.dart';

/// Der vollständige Outdoor-Guide zu einem Spot — genau die Fragen, die
/// Instagram offen lässt: wann, wie lange, wie schwer, wie komme ich hin.
class SpotDetailPage extends StatelessWidget {
  const SpotDetailPage({super.key, required this.spotId});

  final String spotId;

  Future<void> _navigate(BuildContext context, Spot spot) async {
    // Sicherheitswarnung vor der Navigation zu einem Outdoor-Ort — im Moment
    // der Gefahr, gut nachweisbar und rechtlich sinnvoll.
    final proceed = await _showSafetyWarning(context, spot);
    if (proceed != true || !context.mounted) return;

    // Geo-URI funktioniert nativ; im Web öffnet Google Maps im neuen Tab.
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${spot.lat},${spot.lng}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Navigations-App gefunden')),
        );
      }
    }
  }

  Future<bool?> _showSafetyWarning(BuildContext context, Spot spot) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Sicherheitshinweis',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Das Aufsuchen dieses Ortes geschieht auf eigene Gefahr. Angaben zu '
                'Weg, Dauer und Schwierigkeit können ungenau oder veraltet sein.\n\n'
                'Prüfe vorher selbst: Wetter, deine Ausrüstung und Kondition, '
                'örtliche Regeln, Betretungsrechte und Sperrungen. Kehre im Zweifel um.',
                style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                spot.difficulty == Difficulty.hard
                    ? '⛰️ Dieser Spot gilt als anspruchsvoll — nur mit Erfahrung und Ausrüstung.'
                    : 'Bleib auf markierten Wegen und respektiere die Natur.',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Verstanden, los'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final spot = state.spotById(spotId);

    if (spot == null) {
      return const Scaffold(body: Center(child: Text('Spot nicht gefunden')));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _PhotoHeader(spot: spot),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(spot: spot),
                  const SizedBox(height: 18),
                  _FactGrid(spot: spot),
                  const SizedBox(height: 18),
                  _Amenities(spot: spot),
                  const SizedBox(height: 20),
                  Text(
                    spot.description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // PRO: Wetter-Score, Golden Hour, Crowd, Fotografie
                  SpotIntelligencePanel(spot: spot),
                  const SizedBox(height: 22),

                  _GpsRow(spot: spot),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _navigate(context, spot),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Navigation starten'),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _AuthorRow(spot: spot),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final liked = state.isLiked(spot.id);
    final saved = state.isSaved(spot.id);

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: AppTheme.bg,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            PhotoGallery(spot: spot),
            IgnorePointer(child: const PhotoScrim(opacity: 0.6)),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: spot.category.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(spot.category.emoji, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(
                          spot.category.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.isPro && spot.isHiddenGem) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAlt.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '💎 Hidden Gem',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        _RoundAction(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? const Color(0xFFFF4D6D) : Colors.white,
          onTap: () => state.toggleLike(spot.id),
        ),
        _RoundAction(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          color: saved ? AppTheme.accent : Colors.white,
          onTap: () async {
            final ok = await state.toggleSaved(spot.id);
            if (!ok && context.mounted) {
              PaywallPage.show(
                context,
                feature: 'Mehr als ${AppState.freeSaveLimit} gespeicherte Orte',
              );
            }
          },
        ),
        SpotActionsButton(spot: spot),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color ?? Colors.white),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spot.title,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.place, size: 15, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${spot.region}, ${spot.country}',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 20, color: AppTheme.proGold),
              const SizedBox(width: 3),
              Text(
                spot.rating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 5),
              Text(
                '(${spot.ratingCount})',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.favorite, size: 16, color: Color(0xFFFF4D6D)),
              const SizedBox(width: 4),
              Text(
                '${spot.likes}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      );
}

/// Die sechs Kernfakten, die über einen Ausflug entscheiden.
class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Row(
              children: [
                _Fact(
                  icon: Icons.wb_twilight,
                  label: 'Beste Uhrzeit',
                  value: spot.bestTimeOfDay,
                  accent: AppTheme.accent,
                ),
                _Divider(),
                _Fact(
                  icon: Icons.calendar_month,
                  label: 'Saison',
                  value: spot.seasonLabel,
                ),
              ],
            ),
            const Divider(height: 1, indent: 12, endIndent: 12),
            Row(
              children: [
                _Fact(
                  icon: Icons.terrain,
                  label: 'Schwierigkeit',
                  value: spot.difficulty.label,
                  accent: spot.difficulty.color,
                ),
                _Divider(),
                _Fact(
                  icon: Icons.timer_outlined,
                  label: 'Laufzeit',
                  value: spot.hikeLabel,
                ),
              ],
            ),
            const Divider(height: 1, indent: 12, endIndent: 12),
            Row(
              children: [
                _Fact(
                  icon: Icons.straighten,
                  label: 'Strecke',
                  value: spot.hikeKm == 0 ? '—' : '${spot.hikeKm} km',
                ),
                _Divider(),
                _Fact(
                  icon: Icons.landscape,
                  label: 'Höhe',
                  value: '${spot.elevationM} m',
                ),
              ],
            ),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 44, color: const Color(0xFF25313C));
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 19, color: accent ?? AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: accent ?? AppTheme.textPrimary,
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

class _Amenities extends StatelessWidget {
  const _Amenities({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('🅿️', 'Parkplatz', spot.hasParking),
      ('🐕', 'Hunde', spot.dogsAllowed),
      ('👶', 'Kinder', spot.kidsFriendly),
      ('🏕️', 'Camping', spot.campingAllowed),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (emoji, label, ok) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ok
                  ? const Color(0xFF3E9C5A).withValues(alpha: 0.15)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ok
                    ? const Color(0xFF3E9C5A).withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(opacity: ok ? 1 : 0.35, child: Text(emoji)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ok ? AppTheme.textPrimary : AppTheme.textMuted,
                    decoration: ok ? null : TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GpsRow extends StatelessWidget {
  const _GpsRow({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.my_location, size: 18, color: AppTheme.accentAlt),
            const SizedBox(width: 12),
            const Text('GPS', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            const Spacer(),
            SelectableText(
              '${spot.lat.toStringAsFixed(5)}, ${spot.lng.toStringAsFixed(5)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final initials = spot.authorName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join();

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: spot.category.color,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              spot.authorName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              'gepostet vor ${DateTime.now().difference(spot.createdAt).inDays} Tagen',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}
