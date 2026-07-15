import 'package:latlong2/latlong.dart';

import '../models/spot.dart';

/// Baut aus einer Menge Spots einen mehrtägigen Roadtrip.
///
/// Verfahren: Nearest-Neighbour ab Startpunkt, danach Aufteilung auf Tage nach
/// Zeitbudget (Fahrzeit + Wanderzeit + Aufenthalt). Kein Handelsreisenden-Optimum,
/// aber eine Route, die keine unnötigen Kreuzungen fährt — und das in Millisekunden,
/// ohne externen Dienst.
class TripPlanner {
  static const _distance = Distance();

  /// Luftlinie ist zu optimistisch — echte Straßen sind länger.
  static const _roadFactor = 1.35;
  static const _avgSpeedKmh = 65.0;

  /// Wie lange man pro Tag unterwegs sein will (Fahren + Wandern + Fotografieren).
  static const _dayBudgetMinutes = 8 * 60;

  /// Aufenthalt am Spot zusätzlich zur Wanderzeit.
  static const _dwellMinutes = 45;

  static TripPlan plan({
    required List<Spot> spots,
    required int days,
    required LatLng start,
  }) {
    if (spots.isEmpty || days < 1) {
      return const TripPlan(days: [], skipped: []);
    }

    // 1) Reihenfolge: immer zum nächstgelegenen noch nicht besuchten Spot.
    final remaining = [...spots];
    final ordered = <Spot>[];
    var cursor = start;

    while (remaining.isNotEmpty) {
      remaining.sort((a, b) => _km(cursor, a.position).compareTo(_km(cursor, b.position)));
      final next = remaining.removeAt(0);
      ordered.add(next);
      cursor = next.position;
    }

    // 2) Auf Tage verteilen, bis das Zeitbudget des Tages voll ist.
    final result = <TripDay>[];
    var dayIndex = 0;
    var from = start;
    var current = <TripStop>[];
    var currentMinutes = 0.0;

    for (final spot in ordered) {
      if (dayIndex >= days) break;

      final km = _km(from, spot.position) * _roadFactor;
      final driveMin = km / _avgSpeedKmh * 60;
      final stopMin = driveMin + spot.hikeMinutes + _dwellMinutes;

      final wouldOverflow = currentMinutes + stopMin > _dayBudgetMinutes;
      if (wouldOverflow && current.isNotEmpty) {
        result.add(TripDay(
          number: dayIndex + 1,
          stops: current,
          totalMinutes: currentMinutes.round(),
        ));
        dayIndex++;
        if (dayIndex >= days) break;
        current = [];
        currentMinutes = 0;

        // Der neue Tag startet dort, wo der letzte endete.
        final againKm = _km(from, spot.position) * _roadFactor;
        final againDrive = againKm / _avgSpeedKmh * 60;
        current.add(TripStop(
          spot: spot,
          driveKm: againKm,
          driveMinutes: againDrive.round(),
        ));
        currentMinutes = againDrive + spot.hikeMinutes + _dwellMinutes;
      } else {
        current.add(TripStop(
          spot: spot,
          driveKm: km,
          driveMinutes: driveMin.round(),
        ));
        currentMinutes += stopMin;
      }

      from = spot.position;
    }

    if (current.isNotEmpty && dayIndex < days) {
      result.add(TripDay(
        number: dayIndex + 1,
        stops: current,
        totalMinutes: currentMinutes.round(),
      ));
    }

    // Was nicht mehr in die Tage passte.
    final planned = result.expand((d) => d.stops.map((s) => s.spot.id)).toSet();
    final skipped = ordered.where((s) => !planned.contains(s.id)).toList();

    return TripPlan(days: result, skipped: skipped);
  }

  static double _km(LatLng a, LatLng b) => _distance.as(LengthUnit.Kilometer, a, b);
}

class TripPlan {
  const TripPlan({required this.days, required this.skipped});

  final List<TripDay> days;

  /// Spots, die im gewählten Zeitrahmen nicht mehr unterzubringen waren.
  final List<Spot> skipped;

  bool get isEmpty => days.isEmpty;

  double get totalKm =>
      days.fold(0.0, (sum, d) => sum + d.stops.fold(0.0, (s, st) => s + st.driveKm));

  int get totalSpots => days.fold(0, (sum, d) => sum + d.stops.length);
}

class TripDay {
  const TripDay({
    required this.number,
    required this.stops,
    required this.totalMinutes,
  });

  final int number;
  final List<TripStop> stops;
  final int totalMinutes;

  String get durationLabel {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  double get km => stops.fold(0.0, (s, st) => s + st.driveKm);
}

class TripStop {
  const TripStop({
    required this.spot,
    required this.driveKm,
    required this.driveMinutes,
  });

  final Spot spot;
  final double driveKm;
  final int driveMinutes;
}
