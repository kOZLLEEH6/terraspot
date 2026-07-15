import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/spot.dart';
import '../../core/services/trip_planner.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/spot_photo.dart';
import '../spot/spot_detail_page.dart';

/// "Plane einen 4-Tages-Roadtrip" — PRO.
///
/// Nimmt die gespeicherten Spots (oder alle Spots einer Region), sortiert sie zu
/// einer sinnvollen Route und verteilt sie auf Tage.
class TripPlannerPage extends StatefulWidget {
  const TripPlannerPage({super.key});

  @override
  State<TripPlannerPage> createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends State<TripPlannerPage> {
  int _days = 4;
  bool _onlySaved = true;
  TripPlan? _plan;

  /// Startpunkt des Roadtrips. In der finalen App käme der aus dem GPS —
  /// hier ist München voreingestellt, weil dort die meisten Spots erreichbar sind.
  static const _start = LatLng(48.1372, 11.5756);
  static const _startLabel = 'München';

  List<Spot> _candidates(AppState state) {
    final pool = _onlySaved ? state.savedSpots : state.allSpots;
    // Ein Roadtrip über Kontinente ergibt keinen Sinn — auf 1.200 km um den Start begrenzen.
    const d = Distance();
    return pool
        .where((s) => d.as(LengthUnit.Kilometer, _start, s.position) < 1200)
        .toList();
  }

  void _build(AppState state) {
    final spots = _candidates(state);
    setState(() {
      _plan = TripPlanner.plan(spots: spots, days: _days, start: _start);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final candidates = _candidates(state);
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(title: const Text('Routenplaner')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trip_origin, size: 16, color: AppTheme.accentAlt),
                    const SizedBox(width: 8),
                    const Text('Start', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text(
                      _startLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const Divider(height: 22),
                Text(
                  'Dauer: $_days ${_days == 1 ? 'Tag' : 'Tage'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _days.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$_days Tage',
                  onChanged: (v) => setState(() {
                    _days = v.round();
                    _plan = null;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _onlySaved,
                  onChanged: (v) => setState(() {
                    _onlySaved = v;
                    _plan = null;
                  }),
                  title: const Text(
                    'Nur meine gespeicherten Orte',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    _onlySaved
                        ? '${state.savedSpots.length} gespeichert · ${candidates.length} in Reichweite'
                        : 'Alle ${state.allSpots.length} Spots · ${candidates.length} in Reichweite',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: candidates.isEmpty ? null : () => _build(state),
                    icon: const Icon(Icons.route),
                    label: Text(
                      candidates.isEmpty
                          ? 'Keine Spots in Reichweite'
                          : 'Route berechnen',
                    ),
                  ),
                ),
                if (candidates.isEmpty && _onlySaved)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Speichere zuerst ein paar Spots — oder schalte auf "alle Spots" um.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (plan != null && !plan.isEmpty) ...[
            _RouteMap(plan: plan, start: _start),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(label: 'Tage', value: '${plan.days.length}'),
                _Stat(label: 'Spots', value: '${plan.totalSpots}'),
                _Stat(label: 'Fahrt', value: '${plan.totalKm.round()} km'),
              ],
            ),
            const SizedBox(height: 18),
            for (final day in plan.days) _DayCard(day: day),
            if (plan.skipped.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plan.skipped.length} Spots passten nicht in $_days Tage',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.skipped.map((s) => s.title).join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (plan != null && plan.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Keine Route möglich.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.plan, required this.start});

  final TripPlan plan;
  final LatLng start;

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      start,
      for (final d in plan.days)
        for (final s in d.stops) s.spot.position,
    ];

    // Kartenausschnitt so wählen, dass die ganze Route hineinpasst.
    final bounds = LatLngBounds.fromPoints(points);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(36),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.terraspot.app',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 3,
                  color: AppTheme.accent,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: start,
                  width: 26,
                  height: 26,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.accentAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                for (var i = 0; i < points.length - 1; i++)
                  Marker(
                    point: points[i + 1],
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final TripDay day;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              color: AppTheme.surfaceHigh,
              child: Row(
                children: [
                  Text(
                    'Tag ${day.number}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${day.km.round()} km · ${day.durationLabel}',
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            for (final stop in day.stops)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SpotDetailPage(spotId: stop.spot.id),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 62,
                          height: 62,
                          child: SpotPhoto(spot: stop.spot),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.spot.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stop.spot.region}, ${stop.spot.country}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.directions_car,
                                    size: 12, color: AppTheme.textMuted),
                                const SizedBox(width: 3),
                                Text(
                                  '${stop.driveKm.round()} km',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.wb_twilight,
                                    size: 12, color: AppTheme.accent),
                                const SizedBox(width: 3),
                                Text(
                                  stop.spot.bestTimeOfDay,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
