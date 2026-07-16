import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../../core/models/category.dart';
import '../../core/models/spot.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../pro/paywall_page.dart';
import '../spot/spot_detail_page.dart';
import 'cluster.dart';
import 'spot_preview_card.dart';

/// Home: die Weltkarte. Jeder Pin ist ein Spot, die Farbe ist die Kategorie.
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _controller = MapController();

  double _zoom = 3.4;
  bool _heatmap = false;
  bool _darkTiles = true;
  Spot? _selected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSpotTap(Spot spot) {
    setState(() => _selected = spot);
    _controller.move(spot.position, _zoom < 6 ? 6 : _zoom);
  }

  void _onClusterTap(SpotCluster cluster) {
    _controller.move(cluster.center, (_zoom + 2.5).clamp(2, 16));
  }

  void _toggleHeatmap() {
    final state = context.read<AppState>();
    if (!state.isPro) {
      PaywallPage.show(context, feature: 'Die Heatmap');
      return;
    }
    setState(() => _heatmap = !_heatmap);
  }

  bool _locating = false;

  /// Zentriert die Karte auf den echten Gerätestandort und setzt ihn als
  /// Filter-Zentrum, damit Umkreisfilter wie "innerhalb 50 km" funktionieren.
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);

    final result = await context.read<AppState>().locateUser();

    if (!mounted) return;
    setState(() => _locating = false);

    if (result.isSuccess) {
      _controller.move(result.position!, 9);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Standort nicht verfügbar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final spots = state.visibleSpots;
    final clusters = clusterSpots(spots, _zoom);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: const LatLng(46.8, 9.5), // Alpen — dort ist die Dichte am höchsten
              initialZoom: _zoom,
              minZoom: 2.4,
              maxZoom: 17,
              // Hält die Kamera innerhalb der Weltkarte (Web-Mercator endet bei ±85°).
              // Damit gibt es beim Rauszoomen keine grauen Balken über/unter der Karte.
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(-85.05, -180),
                  const LatLng(85.05, 180),
                ),
              ),
              onTap: (_, _) => setState(() => _selected = null),
              onPositionChanged: (pos, _) {
                // Nur bei spürbaren Zoomsprüngen neu clustern — sonst rechnet die
                // Karte während einer Pinch-Geste bei jedem Frame neu.
                if ((pos.zoom - _zoom).abs() > 0.2) {
                  setState(() => _zoom = pos.zoom);
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _darkTiles
                    ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.terraspot.app',
                maxZoom: 19,
              ),
              if (_heatmap) _HeatmapLayer(spots: spots),
              if (state.userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: state.userLocation!,
                      width: 22,
                      height: 22,
                      child: const _UserDot(),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final c in clusters)
                    Marker(
                      point: c.center,
                      width: c.isSingle ? 46 : 52,
                      height: c.isSingle ? 56 : 52,
                      alignment: c.isSingle ? Alignment.topCenter : Alignment.center,
                      child: c.isSingle
                          ? _SpotPin(
                              spot: c.single,
                              selected: _selected?.id == c.single.id,
                              onTap: () => _onSpotTap(c.single),
                            )
                          : _ClusterPin(cluster: c, onTap: () => _onClusterTap(c)),
                    ),
                ],
              ),
              const _Attribution(),
            ],
          ),

          // Kategorie-Legende oben
          SafeArea(
            child: Column(
              children: [
                _TopBar(spotCount: spots.length),
                const _CategoryStrip(),
              ],
            ),
          ),

          // Karten-Werkzeuge rechts
          SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapButton(
                      icon: Icons.local_fire_department,
                      active: _heatmap,
                      pro: !state.isPro,
                      tooltip: 'Heatmap',
                      onTap: _toggleHeatmap,
                    ),
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: _darkTiles ? Icons.dark_mode : Icons.light_mode,
                      tooltip: 'Kartenstil',
                      onTap: () => setState(() => _darkTiles = !_darkTiles),
                    ),
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: Icons.zoom_out_map,
                      tooltip: 'Weltansicht',
                      onTap: () {
                        _controller.move(const LatLng(30, 10), 2.4);
                        setState(() => _selected = null);
                      },
                    ),
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: Icons.my_location,
                      active: _locating,
                      tooltip: 'Mein Standort',
                      onTap: _locateMe,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Vorschaukarte unten, wenn ein Pin gewählt ist
          if (_selected != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SpotPreviewCard(
                    spot: _selected!,
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SpotDetailPage(spotId: _selected!.id),
                      ),
                    ),
                    onClose: () => setState(() => _selected = null),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Pins ---

class _SpotPin extends StatelessWidget {
  const _SpotPin({required this.spot, required this.selected, required this.onTap});

  final Spot spot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = spot.category;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: selected ? 42 : 34,
            height: selected ? 42 : 34,
            decoration: BoxDecoration(
              color: c.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.75),
                width: selected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.color.withValues(alpha: 0.6),
                  blurRadius: selected ? 16 : 8,
                  spreadRadius: selected ? 2 : 0,
                ),
              ],
            ),
            child: Center(
              child: Text(c.emoji, style: TextStyle(fontSize: selected ? 19 : 15)),
            ),
          ),
          // Spitze des Pins
          CustomPaint(
            size: const Size(10, 7),
            painter: _PinTip(color: c.color),
          ),
        ],
      ),
    );
  }
}

/// Der blaue Punkt für die eigene Position — wie in Karten-Apps üblich.
class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2E7DFF),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7DFF).withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
      );
}

class _PinTip extends CustomPainter {
  const _PinTip({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTip old) => old.color != color;
}

class _ClusterPin extends StatelessWidget {
  const _ClusterPin({required this.cluster, required this.onTap});

  final SpotCluster cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Die Farbe des Clusters ist die Farbe seiner häufigsten Kategorie.
    final counts = <SpotCategory, int>{};
    for (final s in cluster.spots) {
      counts[s.category] = (counts[s.category] ?? 0) + 1;
    }
    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: dominant.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2.5),
          boxShadow: [
            BoxShadow(color: dominant.color.withValues(alpha: 0.55), blurRadius: 14),
          ],
        ),
        child: Center(
          child: Text(
            '${cluster.spots.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Heatmap (PRO) ---

/// Dichte-Darstellung statt einzelner Pins: überlappende, weiche Kreise, deren
/// Radius mit der Beliebtheit wächst. Wo sich viele Spots überlagern, addiert
/// sich die Deckkraft zu einem heißen Kern.
class _HeatmapLayer extends StatelessWidget {
  const _HeatmapLayer({required this.spots});

  final List<Spot> spots;

  @override
  Widget build(BuildContext context) {
    final circles = <CircleMarker>[];

    for (final s in spots) {
      final weight = (s.likes / 9000).clamp(0.15, 1.0);
      final baseRadius = 28000 + weight * 90000; // Meter

      // Drei Ringe erzeugen den weichen Verlauf.
      circles.add(CircleMarker(
        point: s.position,
        radius: baseRadius * 2.1,
        useRadiusInMeter: true,
        color: const Color(0xFF3D5AFE).withValues(alpha: 0.10 * weight),
        borderStrokeWidth: 0,
      ));
      circles.add(CircleMarker(
        point: s.position,
        radius: baseRadius * 1.2,
        useRadiusInMeter: true,
        color: AppTheme.accent.withValues(alpha: 0.18 * weight),
        borderStrokeWidth: 0,
      ));
      circles.add(CircleMarker(
        point: s.position,
        radius: baseRadius * 0.55,
        useRadiusInMeter: true,
        color: const Color(0xFFFF3D00).withValues(alpha: 0.30 * weight),
        borderStrokeWidth: 0,
      ));
    }

    return CircleLayer(circles: circles);
  }
}

// --- Kopfzeile & Legende ---

class _TopBar extends StatelessWidget {
  const _TopBar({required this.spotCount});

  final int spotCount;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final filters = state.filters;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/branding/icon.png',
                    width: 24,
                    height: 24,
                    cacheWidth: 72,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TerraSpot',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  color: AppTheme.textMuted.withValues(alpha: 0.3),
                ),
                Text(
                  '$spotCount',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (filters.activeCount > 0) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: state.clearFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${filters.activeCount}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.close, size: 12, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          if (state.isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.proGold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.proGold.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium, size: 15, color: AppTheme.proGold),
                  SizedBox(width: 5),
                  Text(
                    'PRO',
                    style: TextStyle(
                      color: AppTheme.proGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Die Kategorie-Legende ist gleichzeitig der schnellste Filter.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final active = state.filters.categories;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: SpotCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = SpotCategory.values[i];
          final on = active.contains(c);
          return GestureDetector(
            onTap: () {
              final next = Set<SpotCategory>.of(active);
              on ? next.remove(c) : next.add(c);
              state.setFilters(state.filters.copyWith(categories: next));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: on ? c.color : AppTheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: on ? c.color : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Text(c.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                      color: on ? Colors.white : AppTheme.textPrimary,
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

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.pro = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final bool pro;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active ? AppTheme.accent : AppTheme.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: active ? Colors.black : AppTheme.textPrimary,
                  ),
                ),
                if (pro)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.proGold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) => const RichAttributionWidget(
        alignment: AttributionAlignment.bottomLeft,
        attributions: [
          TextSourceAttribution('OpenStreetMap contributors'),
          TextSourceAttribution('CARTO'),
        ],
      );
}
