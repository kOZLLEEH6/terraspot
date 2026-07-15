import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/models/spot.dart';

/// Eine Gruppe von Spots, die auf dem Bildschirm zu nah beieinander liegen.
class SpotCluster {
  SpotCluster(this.spots) : center = _centroid(spots);

  final List<Spot> spots;
  final LatLng center;

  bool get isSingle => spots.length == 1;
  Spot get single => spots.first;

  static LatLng _centroid(List<Spot> spots) {
    var lat = 0.0;
    var lng = 0.0;
    for (final s in spots) {
      lat += s.lat;
      lng += s.lng;
    }
    return LatLng(lat / spots.length, lng / spots.length);
  }
}

/// Gruppiert Spots, die beim aktuellen Zoom näher als [gridPx] Pixel beieinander liegen.
///
/// Ohne das überlagern sich in Mitteleuropa bei Weltzoom ein Dutzend Pins zu einem Klumpen.
/// Statt eine Cluster-Bibliothek einzubinden, projizieren wir selbst nach Web-Mercator
/// und rastern das Ergebnis — bei einigen tausend Spots völlig ausreichend.
List<SpotCluster> clusterSpots(List<Spot> spots, double zoom, {double gridPx = 76}) {
  if (spots.isEmpty) return const [];

  final scale = 256.0 * math.pow(2, zoom);
  final buckets = <String, List<Spot>>{};

  for (final spot in spots) {
    final p = _project(spot.position, scale);
    final key = '${(p.dx / gridPx).floor()}:${(p.dy / gridPx).floor()}';
    buckets.putIfAbsent(key, () => []).add(spot);
  }

  return buckets.values.map(SpotCluster.new).toList();
}

/// Web-Mercator: Lat/Lng -> Pixelkoordinate bei gegebener Weltgröße.
_Point _project(LatLng p, double scale) {
  final latRad = p.latitude * math.pi / 180.0;
  final x = (p.longitude + 180.0) / 360.0 * scale;
  final sinLat = math.sin(latRad.clamp(-1.4844, 1.4844)); // Mercator-Pole abschneiden
  final y = (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
  return _Point(x, y);
}

class _Point {
  const _Point(this.dx, this.dy);
  final double dx;
  final double dy;
}
