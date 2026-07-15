import 'dart:math' as math;

import '../models/category.dart';
import '../models/spot.dart';
import 'sun_service.dart';
import 'weather_service.dart';

/// "Wann lohnt sich der Spot?" — kombiniert echtes Wetter (Open-Meteo) mit
/// echter Astronomie (SunService) zu einer 0-5-Sterne-Bewertung pro Tag.
///
/// Das ist ein transparentes, regelbasiertes Modell: jede Kategorie hat andere
/// Idealbedingungen. Ein Sonnenaufgang braucht Wolken (sonst kein Farbspiel),
/// ein Nachthimmel darf keine haben. Jeder Score liefert die Gründe mit, damit
/// der Nutzer nachvollziehen kann, warum ein Tag gut oder schlecht ist.
class ScoreService {
  /// Bewertet einen Tag für einen Spot.
  static SpotScore score(Spot spot, DailyWeather w, {DateTime? date}) {
    final day = date ?? w.date;
    final reasons = <ScoreReason>[];

    double stars;
    switch (spot.category) {
      case SpotCategory.sunrise:
      case SpotCategory.viewpoint:
        stars = _dramaticLight(w, reasons);
      case SpotCategory.nightSky:
        stars = _nightSky(spot, w, day, reasons);
      case SpotCategory.waterfall:
        stars = _waterfall(w, reasons);
      case SpotCategory.flowers:
      case SpotCategory.autumn:
        stars = _gentleOutdoor(w, reasons);
      case SpotCategory.winter:
        stars = _winter(w, reasons);
      case SpotCategory.beach:
        stars = _beach(w, reasons);
      case SpotCategory.hiking:
        stars = _hiking(w, reasons);
      case SpotCategory.camping:
      case SpotCategory.campfire:
        stars = _camping(w, reasons);
    }

    // Saison-Malus: ein Herbstspot im Mai bleibt ein Herbstspot.
    if (!spot.bestMonths.contains(day.month) && spot.bestMonths.isNotEmpty) {
      stars -= 1.0;
      reasons.add(ScoreReason(
        'Außerhalb der besten Saison (${spot.seasonLabel})',
        ScoreImpact.negative,
      ));
    } else if (spot.bestMonths.isNotEmpty) {
      reasons.add(ScoreReason('Beste Saison für diesen Spot', ScoreImpact.positive));
    }

    stars = stars.clamp(0.0, 5.0);
    return SpotScore(date: day, stars: stars, reasons: reasons, weather: w);
  }

  /// Bewertet die nächsten Tage.
  static List<SpotScore> forecast(Spot spot, List<DailyWeather> days) =>
      days.map((w) => score(spot, w)).toList();

  // --- Kategorie-Modelle ---

  /// Sonnenaufgang & Aussicht: Die besten Bilder entstehen NICHT bei 0% Wolken.
  /// Ideal sind ca. 30-60% hohe Wolken — sie fangen das Licht ein.
  static double _dramaticLight(DailyWeather w, List<ScoreReason> reasons) {
    var s = 5.0;

    final c = w.cloudCover;
    if (c < 10) {
      s -= 1.2;
      reasons.add(ScoreReason(
        'Wolkenloser Himmel (${c.round()}%) — klar, aber wenig Farbspiel',
        ScoreImpact.neutral,
      ));
    } else if (c >= 25 && c <= 65) {
      reasons.add(ScoreReason(
        'Ideale Wolkendecke (${c.round()}%) — perfekt für dramatisches Licht',
        ScoreImpact.positive,
      ));
    } else if (c > 85) {
      s -= 2.5;
      reasons.add(ScoreReason(
        'Zu bedeckt (${c.round()}%) — Sonne bleibt hinter der Wolkendecke',
        ScoreImpact.negative,
      ));
    } else {
      s -= 0.6;
      reasons.add(ScoreReason('Wolkendecke ${c.round()}%', ScoreImpact.neutral));
    }

    s -= _rainPenalty(w, reasons, weight: 2.5);
    s -= _fogPenalty(w, reasons);
    return s;
  }

  /// Nachthimmel: jede Wolke ist ein Feind, der Mond auch.
  static double _nightSky(Spot spot, DailyWeather w, DateTime day, List<ScoreReason> reasons) {
    var s = 5.0;

    final c = w.cloudCover;
    if (c <= 15) {
      reasons.add(ScoreReason('Klarer Himmel (${c.round()}% Wolken)', ScoreImpact.positive));
    } else if (c <= 35) {
      s -= 1.5;
      reasons.add(ScoreReason('Leicht bewölkt (${c.round()}%)', ScoreImpact.neutral));
    } else {
      s -= 3.5;
      reasons.add(ScoreReason(
        'Zu bewölkt (${c.round()}%) — Sterne kaum sichtbar',
        ScoreImpact.negative,
      ));
    }

    final moon = SunService.moon(day, spot.lat, spot.lng);
    final ill = moon.illumination;
    if (ill < 0.2) {
      reasons.add(ScoreReason(
        '${moon.emoji} ${moon.phaseLabel} (${(ill * 100).round()}%) — dunkler Himmel',
        ScoreImpact.positive,
      ));
    } else if (ill < 0.5) {
      s -= 0.8;
      reasons.add(ScoreReason(
        '${moon.emoji} ${moon.phaseLabel} (${(ill * 100).round()}% beleuchtet)',
        ScoreImpact.neutral,
      ));
    } else {
      s -= 1.8;
      reasons.add(ScoreReason(
        '${moon.emoji} ${moon.phaseLabel} (${(ill * 100).round()}%) — überstrahlt die Sterne',
        ScoreImpact.negative,
      ));
    }

    final mw = SunService.milkyWay(day, spot.lat, spot.lng);
    if (mw.visible) {
      s += 0.5;
      reasons.add(ScoreReason('Milchstraßen-Zentrum sichtbar', ScoreImpact.positive));
    }

    // Hohe Luftfeuchtigkeit = Dunst, schlechte Transparenz.
    if (w.humidity > 85) {
      s -= 0.7;
      reasons.add(ScoreReason(
        'Hohe Luftfeuchtigkeit (${w.humidity.round()}%) — dunstiger Himmel',
        ScoreImpact.negative,
      ));
    }

    s -= _rainPenalty(w, reasons, weight: 3.0);
    return s;
  }

  /// Wasserfall: Regen der Tage davor füllt ihn — Regen währenddessen ruiniert die Kamera.
  /// Bedeckter Himmel ist hier ein Vorteil (weiches Licht, Langzeitbelichtung).
  static double _waterfall(DailyWeather w, List<ScoreReason> reasons) {
    var s = 5.0;

    final c = w.cloudCover;
    if (c >= 40) {
      reasons.add(ScoreReason(
        'Bedeckt (${c.round()}%) — weiches Licht, ideal für Langzeitbelichtung',
        ScoreImpact.positive,
      ));
    } else if (c < 15) {
      s -= 1.0;
      reasons.add(ScoreReason(
        'Grelle Sonne (${c.round()}% Wolken) — harte Kontraste im Wasser',
        ScoreImpact.negative,
      ));
    }

    if (w.precipitationMm > 0.5 && w.precipitationMm < 6) {
      reasons.add(ScoreReason(
        'Etwas Niederschlag (${w.precipitationMm.toStringAsFixed(1)} mm) — der Fall führt gut Wasser',
        ScoreImpact.positive,
      ));
    } else if (w.precipitationMm >= 6) {
      s -= 2.0;
      reasons.add(ScoreReason(
        'Starker Regen (${w.precipitationMm.toStringAsFixed(1)} mm) — Wege rutschig, Ausrüstung gefährdet',
        ScoreImpact.negative,
      ));
    }

    if (w.tempMax < 0) {
      s -= 1.0;
      reasons.add(ScoreReason('Frost — Wege vereist', ScoreImpact.negative));
    }
    return s;
  }

  static double _gentleOutdoor(DailyWeather w, List<ScoreReason> reasons) {
    var s = 5.0;
    s -= _rainPenalty(w, reasons, weight: 3.0);
    s -= _windPenalty(w, reasons, threshold: 25, weight: 1.5);
    if (w.cloudCover > 80) {
      s -= 1.0;
      reasons.add(ScoreReason('Trübes Licht (${w.cloudCover.round()}% Wolken)', ScoreImpact.negative));
    } else if (w.cloudCover < 40) {
      reasons.add(ScoreReason('Freundliches Licht', ScoreImpact.positive));
    }
    return s;
  }

  static double _winter(DailyWeather w, List<ScoreReason> reasons) {
    var s = 5.0;
    if (w.tempMax > 5) {
      s -= 2.0;
      reasons.add(ScoreReason(
        'Zu mild (${w.tempMax.round()}°C) — Schnee taut',
        ScoreImpact.negative,
      ));
    } else {
      reasons.add(ScoreReason('${w.tempMax.round()}°C — Schnee bleibt liegen', ScoreImpact.positive));
    }
    if (w.weatherCode >= 71 && w.weatherCode <= 77) {
      reasons.add(ScoreReason('Schneefall — frische Decke', ScoreImpact.positive));
    }
    s -= _windPenalty(w, reasons, threshold: 35, weight: 1.5);
    return s;
  }

  static double _beach(DailyWeather w, List<ScoreReason> reasons) {
    var s = 5.0;
    if (w.tempMax >= 22) {
      reasons.add(ScoreReason('${w.tempMax.round()}°C — Badewetter', ScoreImpact.positive));
    } else if (w.tempMax < 15) {
      s -= 1.5;
      reasons.add(ScoreReason('Nur ${w.tempMax.round()}°C', ScoreImpact.negative));
    }
    if (w.cloudCover < 30) {
      reasons.add(ScoreReason('Sonnig (${w.cloudCover.round()}% Wolken)', ScoreImpact.positive));
    } else if (w.cloudCover > 70) {
      s -= 1.5;
      reasons.add(ScoreReason('Bedeckt (${w.cloudCover.round()}%)', ScoreImpact.negative));
    }
    s -= _rainPenalty(w, reasons, weight: 3.0);
    s -= _windPenalty(w, reasons, threshold: 30, weight: 1.0);
    return s;
  }

  static double _hiking(DailyWeather w, List<ScoreReason> reasons) {
    var s = 5.0;
    s -= _rainPenalty(w, reasons, weight: 3.0);
    if (w.tempMax > 30) {
      s -= 1.5;
      reasons.add(ScoreReason('${w.tempMax.round()}°C — zu heiß zum Wandern', ScoreImpact.negative));
    } else if (w.tempMax >= 12 && w.tempMax <= 24) {
      reasons.add(ScoreReason('${w.tempMax.round()}°C — angenehme Wandertemperatur', ScoreImpact.positive));
    }
    s -= _windPenalty(w, reasons, threshold: 40, weight: 1.5);
    s -= _fogPenalty(w, reasons);
    return s;
  }

  static double _camping(DailyWeather w, List<ScoreReason> reasons) {
    var s = 5.0;
    s -= _rainPenalty(w, reasons, weight: 3.5);
    s -= _windPenalty(w, reasons, threshold: 25, weight: 2.0);
    if (w.tempMin < 0) {
      s -= 1.0;
      reasons.add(ScoreReason('Nachtfrost (${w.tempMin.round()}°C)', ScoreImpact.negative));
    } else if (w.tempMin >= 8) {
      reasons.add(ScoreReason('Milde Nacht (${w.tempMin.round()}°C)', ScoreImpact.positive));
    }
    return s;
  }

  // --- gemeinsame Straf-Terme ---

  static double _rainPenalty(DailyWeather w, List<ScoreReason> reasons, {required double weight}) {
    final p = w.precipitationProbability / 100.0;
    if (p < 0.15) {
      reasons.add(ScoreReason('Kaum Regenrisiko (${w.precipitationProbability.round()}%)',
          ScoreImpact.positive));
      return 0;
    }
    if (p >= 0.6) {
      reasons.add(ScoreReason(
        'Hohes Regenrisiko (${w.precipitationProbability.round()}%)',
        ScoreImpact.negative,
      ));
    } else if (p >= 0.3) {
      reasons.add(ScoreReason(
        'Regenrisiko ${w.precipitationProbability.round()}%',
        ScoreImpact.neutral,
      ));
    }
    return p * weight;
  }

  static double _windPenalty(
    DailyWeather w,
    List<ScoreReason> reasons, {
    required double threshold,
    required double weight,
  }) {
    if (w.windSpeedKmh <= threshold) return 0;
    final over = (w.windSpeedKmh - threshold) / threshold;
    reasons.add(ScoreReason(
      'Kräftiger Wind (${w.windSpeedKmh.round()} km/h)',
      ScoreImpact.negative,
    ));
    return math.min(over * weight, weight);
  }

  static double _fogPenalty(DailyWeather w, List<ScoreReason> reasons) {
    if (w.weatherCode >= 45 && w.weatherCode <= 48) {
      reasons.add(ScoreReason('Nebel — keine Fernsicht', ScoreImpact.negative));
      return 2.0;
    }
    return 0;
  }

  // --- Crowd Prediction ---

  /// Schätzt, wie voll ein Spot an einem Tag wird.
  ///
  /// Heuristik aus Popularität × Wochentag × Wetter × Saison. Sobald echte
  /// Check-in-Daten existieren, ersetzt ein trainiertes Modell diese Funktion —
  /// die Signatur bleibt gleich.
  static CrowdPrediction crowd(Spot spot, DailyWeather w, {DateTime? date}) {
    final day = date ?? w.date;

    // Referenz: ~2.000 Besucher/Tag entsprechen Index 1,0. So bleibt bei den
    // beliebtesten Spots (bis 5.000/Tag) genug Spielraum, damit Wetter und
    // Wochentag den Andrang zwischen den Stufen verschieben statt oben zu sättigen.
    var index = spot.visitorsPerDay / 2000.0;

    // Wochenende zieht deutlich mehr Menschen an.
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    if (isWeekend) index *= 1.8;
    if (day.weekday == DateTime.friday) index *= 1.2;

    // Gutes Wetter füllt die Parkplätze.
    final goodWeather = w.precipitationProbability < 30 && w.cloudCover < 70;
    if (goodWeather) {
      index *= 1.4;
    } else if (w.precipitationProbability > 60) {
      index *= 0.5;
    }

    // Hochsaison.
    if (spot.bestMonths.contains(day.month)) index *= 1.3;

    // Frühe Uhrzeiten sind fast immer leer — Sonnenaufgangs-Spots filtern sich selbst.
    if (spot.category == SpotCategory.sunrise || spot.category == SpotCategory.nightSky) {
      index *= 0.35;
    }

    // Schwere Wanderungen halten Gelegenheitsbesucher fern.
    switch (spot.difficulty) {
      case Difficulty.easy:
        index *= 1.2;
      case Difficulty.medium:
        index *= 0.85;
      case Difficulty.hard:
        index *= 0.45;
    }

    final level = switch (index) {
      < 0.35 => CrowdLevel.empty,
      < 0.8 => CrowdLevel.moderate,
      < 1.5 => CrowdLevel.busy,
      _ => CrowdLevel.packed,
    };

    final drivers = <String>[];
    if (isWeekend) drivers.add('Wochenende');
    if (goodWeather) drivers.add('gutes Wetter');
    if (w.precipitationProbability > 60) drivers.add('Regen hält Besucher fern');
    if (spot.difficulty == Difficulty.hard) drivers.add('anspruchsvoller Aufstieg');
    if (spot.category == SpotCategory.sunrise) drivers.add('frühe Uhrzeit');

    return CrowdPrediction(date: day, level: level, drivers: drivers);
  }
}

enum ScoreImpact { positive, neutral, negative }

class ScoreReason {
  const ScoreReason(this.text, this.impact);
  final String text;
  final ScoreImpact impact;
}

class SpotScore {
  const SpotScore({
    required this.date,
    required this.stars,
    required this.reasons,
    required this.weather,
  });

  final DateTime date;
  final double stars;
  final List<ScoreReason> reasons;
  final DailyWeather weather;

  int get fullStars => stars.round().clamp(0, 5);

  String get headline => switch (stars) {
        >= 4.5 => 'Perfekte Bedingungen',
        >= 3.5 => 'Lohnt sich',
        >= 2.5 => 'Durchwachsen',
        >= 1.5 => 'Eher nicht',
        _ => 'Heute nicht',
      };
}

enum CrowdLevel {
  empty('Leer', '🟢'),
  moderate('Mäßig besucht', '🟡'),
  busy('Voll', '🟠'),
  packed('Sehr voll', '🔴');

  const CrowdLevel(this.label, this.emoji);
  final String label;
  final String emoji;
}

class CrowdPrediction {
  const CrowdPrediction({
    required this.date,
    required this.level,
    required this.drivers,
  });

  final DateTime date;
  final CrowdLevel level;
  final List<String> drivers;
}
