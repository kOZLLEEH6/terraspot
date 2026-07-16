import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:terraspot/core/data/mock_data.dart';
import 'package:terraspot/core/data/spot_repository.dart';
import 'package:terraspot/core/models/category.dart';
import 'package:terraspot/core/models/filters.dart';
import 'package:terraspot/core/services/nl_search_service.dart';
import 'package:terraspot/core/services/score_service.dart';
import 'package:terraspot/core/services/sun_service.dart';
import 'package:terraspot/core/services/trip_planner.dart';
import 'package:terraspot/core/services/weather_service.dart';
import 'package:terraspot/core/state/app_state.dart';

void main() {
  group('SunService', () {
    test('Sonnenaufgang in Berlin zur Sommersonnenwende liegt gegen 02:45 UTC', () {
      // Berlin 52,52 N / 13,40 O. Sonnenaufgang ~04:45 MESZ = 02:45 UTC.
      final t = SunService.times(DateTime.utc(2025, 6, 21), 52.52, 13.40);

      expect(t.sunrise, isNotNull);
      final minutes = t.sunrise!.hour * 60 + t.sunrise!.minute;
      expect(minutes, inInclusiveRange(2 * 60 + 30, 3 * 60));
    });

    test('Sonnenaufgang liegt vor, Sonnenuntergang nach dem Sonnenhöchststand', () {
      final t = SunService.times(DateTime.utc(2025, 3, 20), 46.6, 11.7);

      expect(t.sunrise!.isBefore(t.solarNoon), isTrue);
      expect(t.sunset!.isAfter(t.solarNoon), isTrue);
    });

    test('Am Äquinoktium dauert der Tag am Äquator rund 12 Stunden', () {
      final t = SunService.times(DateTime.utc(2025, 3, 20), 0, 0);
      final dayLength = t.sunset!.difference(t.sunrise!).inMinutes;

      expect(dayLength, inInclusiveRange(11 * 60 + 50, 12 * 60 + 20));
    });

    test('Nordkap im Juni: Polartag, kein Sonnenaufgang', () {
      final t = SunService.times(DateTime.utc(2025, 6, 21), 71.17, 25.78);

      expect(t.polarDay, isTrue);
      expect(t.sunrise, isNull);
    });

    test('Blaue Stunde kommt vor dem Sonnenaufgang, goldene danach', () {
      final t = SunService.times(DateTime.utc(2025, 9, 15), 46.6, 11.7);

      expect(t.blueHourMorningStart!.isBefore(t.sunrise!), isTrue);
      expect(t.goldenHourMorningEnd!.isAfter(t.sunrise!), isTrue);
      expect(t.goldenHourMorningEnd!.isBefore(t.solarNoon), isTrue);
    });

    test('Mondbeleuchtung bleibt über einen ganzen Monat zwischen 0 und 1', () {
      for (var d = 0; d < 30; d++) {
        final moon = SunService.moon(DateTime.utc(2025, 1, 1).add(Duration(days: d)),
            46.6, 11.7);
        expect(moon.illumination, inInclusiveRange(0.0, 1.0));
        expect(moon.phase, inInclusiveRange(0.0, 1.0));
      }
    });

    test('Sonne steht mittags über und nachts unter dem Horizont', () {
      final noon = SunService.sunPosition(DateTime.utc(2025, 6, 21, 11), 48.0, 0.0);
      final night = SunService.sunPosition(DateTime.utc(2025, 6, 21, 23), 48.0, 0.0);

      expect(noon.altitudeDeg, greaterThan(0));
      expect(night.altitudeDeg, lessThan(0));
    });
  });

  group('ScoreService', () {
    final spots = buildMockSpots();
    final nightSky = spots.firstWhere((s) => s.category == SpotCategory.nightSky);
    final sunrise = spots.firstWhere((s) => s.category == SpotCategory.sunrise);

    DailyWeather weather({
      required double cloud,
      required double rainProb,
      int code = 0,
      double tempMax = 15,
      double tempMin = 8,
      double rainMm = 0,
      double wind = 8,
      double humidity = 60,
    }) =>
        DailyWeather(
          date: DateTime(2025, 9, 15),
          weatherCode: code,
          tempMax: tempMax,
          tempMin: tempMin,
          precipitationMm: rainMm,
          precipitationProbability: rainProb,
          cloudCover: cloud,
          windSpeedKmh: wind,
          humidity: humidity,
        );

    test('Nachthimmel: klar schlägt bedeckt deutlich', () {
      final clear = ScoreService.score(nightSky, weather(cloud: 5, rainProb: 0));
      final overcast = ScoreService.score(nightSky, weather(cloud: 95, rainProb: 10));

      expect(clear.stars, greaterThan(overcast.stars));
      expect(overcast.stars, lessThan(2.5));
    });

    test('Sonnenaufgang: etwas Wolke schlägt gar keine Wolke', () {
      final some = ScoreService.score(sunrise, weather(cloud: 45, rainProb: 5));
      final none = ScoreService.score(sunrise, weather(cloud: 2, rainProb: 5));

      expect(some.stars, greaterThan(none.stars));
    });

    test('Score bleibt für jeden Spot und jedes Wetter zwischen 0 und 5', () {
      for (final spot in spots) {
        for (final cloud in [0.0, 50.0, 100.0]) {
          for (final rain in [0.0, 100.0]) {
            final s = ScoreService.score(spot, weather(cloud: cloud, rainProb: rain));
            expect(s.stars, inInclusiveRange(0.0, 5.0), reason: spot.title);
          }
        }
      }
    });

    test('Jeder Score nennt mindestens einen Grund', () {
      for (final spot in spots.take(10)) {
        final s = ScoreService.score(spot, weather(cloud: 40, rainProb: 20));
        expect(s.reasons, isNotEmpty, reason: spot.title);
      }
    });

    test('Crowd: Sonne am Samstag ist voller als Regen am Dienstag', () {
      final hallstatt = spots.firstWhere((s) => s.id == 'hallstatt');

      final busy = ScoreService.crowd(
        hallstatt,
        weather(cloud: 10, rainProb: 5),
        date: DateTime(2025, 9, 13), // Samstag
      );
      final quiet = ScoreService.crowd(
        hallstatt,
        weather(cloud: 95, rainProb: 90),
        date: DateTime(2025, 9, 16), // Dienstag
      );

      expect(busy.level.index, greaterThan(quiet.level.index));
    });
  });

  group('NlSearchService', () {
    test('erkennt Kategorie, Schwierigkeit, Distanz und Hunde in einem Satz', () {
      final r = NlSearchService.parse(
        'Ich möchte eine leichte Wanderung mit Wasserfall unter 5 km, Hunde erlaubt',
        const SpotFilters(),
      );

      expect(r.filters.categories, contains(SpotCategory.waterfall));
      expect(r.filters.categories, contains(SpotCategory.hiking));
      expect(r.filters.difficulties, contains(Difficulty.easy));
      expect(r.filters.maxHikeKm, 5);
      expect(r.filters.dogsAllowed, isTrue);
      expect(r.understood, isNotEmpty);
    });

    test('erkennt Hidden Gems und Nachthimmel', () {
      final r = NlSearchService.parse(
        'ruhiger Spot für Sternenhimmel, nicht überlaufen',
        const SpotFilters(),
      );

      expect(r.filters.categories, contains(SpotCategory.nightSky));
      expect(r.filters.onlyHiddenGems, isTrue);
    });

    test('die erkannten Filter liefern auch tatsächlich passende Spots', () {
      final spots = buildMockSpots();
      final r = NlSearchService.parse(
        'Wasserfall, Hunde erlaubt, Parkplatz',
        const SpotFilters(),
      );
      final hits = spots.where(r.filters.matches).toList();

      expect(hits, isNotEmpty);
      expect(hits.every((s) => s.category == SpotCategory.waterfall), isTrue);
      expect(hits.every((s) => s.dogsAllowed && s.hasParking), isTrue);
    });
  });

  group('TripPlanner', () {
    test('verteilt Spots auf Tage, ohne zu doppeln oder zu verlieren', () {
      final spots = buildMockSpots()
          .where((s) => s.country == 'Deutschland' || s.country == 'Österreich')
          .toList();

      final plan = TripPlanner.plan(
        spots: spots,
        days: 3,
        start: const LatLng(48.1372, 11.5756),
      );

      final planned = plan.days.expand((d) => d.stops.map((s) => s.spot.id)).toList();

      expect(planned.toSet().length, planned.length, reason: 'keine Duplikate');
      expect(plan.days.length, lessThanOrEqualTo(3));
      expect(
        planned.length + plan.skipped.length,
        spots.length,
        reason: 'jeder Spot ist eingeplant oder als übrig ausgewiesen',
      );
    });

    test('leere Eingabe ergibt einen leeren Plan', () {
      final plan = TripPlanner.plan(
        spots: const [],
        days: 3,
        start: const LatLng(48.1, 11.5),
      );

      expect(plan.isEmpty, isTrue);
    });
  });

  group('Mock-Daten', () {
    final spots = buildMockSpots();

    test('30 Spots mit eindeutigen IDs', () {
      expect(spots.length, 30);
      expect(spots.map((s) => s.id).toSet().length, 30);
    });

    test('alle Koordinaten liegen im gültigen Bereich', () {
      for (final s in spots) {
        expect(s.lat, inInclusiveRange(-90, 90), reason: s.title);
        expect(s.lng, inInclusiveRange(-180, 180), reason: s.title);
      }
    });

    test('jeder Spot hat Fotos und gültige Monate', () {
      for (final s in spots) {
        expect(s.photoUrls, isNotEmpty, reason: s.title);
        expect(s.bestMonths, isNotEmpty, reason: s.title);
        for (final m in s.bestMonths) {
          expect(m, inInclusiveRange(1, 12), reason: s.title);
        }
      }
    });

    test('es gibt Hidden Gems, aber nicht jeder Spot ist einer', () {
      final gems = spots.where((s) => s.isHiddenGem).toList();

      expect(gems, isNotEmpty);
      expect(gems.length, lessThan(spots.length ~/ 2));
    });

    test('photoCount stimmt für kuratierte Spots', () {
      // Kuratierte Spots haben kein lokales Foto -> Anzahl = photoUrls.
      for (final s in spots) {
        expect(s.photoCount, s.photoUrls.length, reason: s.title);
        expect(s.photoCount, greaterThan(0), reason: s.title);
      }
    });
  });

  group('GiftCode', () {
    test('JSON-Roundtrip erhält alle Felder', () {
      final gc = GiftCode(
        code: 'TERRA-ABCD-EFGH',
        months: 3,
        createdAt: DateTime(2026, 1, 1),
      ).markRedeemed();

      final back = GiftCode.fromJson(gc.toJson());
      expect(back.code, 'TERRA-ABCD-EFGH');
      expect(back.months, 3);
      expect(back.redeemed, isTrue);
      expect(back.redeemedAt, isNotNull);
    });
  });

  group('SpotReport', () {
    test('JSON-Roundtrip erhält alle Felder', () {
      final r = SpotReport(
        id: 'r_1',
        spotId: 'seceda',
        reason: 'Spam',
        reporter: 'Tester',
        createdAt: DateTime(2026, 2, 3, 12, 30),
      );

      final back = SpotReport.fromJson(r.toJson());
      expect(back.id, 'r_1');
      expect(back.spotId, 'seceda');
      expect(back.reason, 'Spam');
      expect(back.reporter, 'Tester');
      expect(back.createdAt, DateTime(2026, 2, 3, 12, 30));
    });
  });
}
