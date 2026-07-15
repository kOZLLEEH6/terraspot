import 'dart:math' as math;

/// Astronomie-Rechner für Sonne und Mond.
///
/// Portierung der SunCalc-Algorithmen (Meeus, "Astronomical Algorithms") nach Dart.
/// Genauigkeit: Sonnenzeiten ~1 Minute, Mondposition wenige Bogenminuten — mehr als
/// ausreichend für Fotografie-Planung.
///
/// Alle Rückgaben sind UTC. Die UI rechnet über [localOffsetFor] in die
/// Ortszeit am Spot um (Näherung über den Längengrad, ohne Zeitzonendatenbank).
class SunService {
  static const _rad = math.pi / 180.0;
  static const _dayMs = 86400000.0;
  static const _j1970 = 2440588.0;
  static const _j2000 = 2451545.0;

  /// Schiefe der Ekliptik.
  static const _e = _rad * 23.4397;

  // --- Julianische Daten ---

  static double _toJulian(DateTime date) =>
      date.toUtc().millisecondsSinceEpoch / _dayMs - 0.5 + _j1970;

  static DateTime _fromJulian(double j) => DateTime.fromMillisecondsSinceEpoch(
        ((j + 0.5 - _j1970) * _dayMs).round(),
        isUtc: true,
      );

  static double _toDays(DateTime date) => _toJulian(date) - _j2000;

  // --- Positionsrechnung ---

  static double _rightAscension(double l, double b) =>
      math.atan2(math.sin(l) * math.cos(_e) - math.tan(b) * math.sin(_e), math.cos(l));

  static double _declination(double l, double b) =>
      math.asin(math.sin(b) * math.cos(_e) + math.cos(b) * math.sin(_e) * math.sin(l));

  static double _azimuth(double h, double phi, double dec) =>
      math.atan2(math.sin(h), math.cos(h) * math.sin(phi) - math.tan(dec) * math.cos(phi));

  static double _altitude(double h, double phi, double dec) => math.asin(
      math.sin(phi) * math.sin(dec) + math.cos(phi) * math.cos(dec) * math.cos(h));

  static double _siderealTime(double d, double lw) => _rad * (280.16 + 360.9856235 * d) - lw;

  static double _solarMeanAnomaly(double d) => _rad * (357.5291 + 0.98560028 * d);

  static double _eclipticLongitude(double m) {
    final c = _rad * (1.9148 * math.sin(m) + 0.02 * math.sin(2 * m) + 0.0003 * math.sin(3 * m));
    const p = _rad * 102.9372; // Perihel der Erde
    return m + c + p + math.pi;
  }

  static ({double dec, double ra}) _sunCoords(double d) {
    final m = _solarMeanAnomaly(d);
    final l = _eclipticLongitude(m);
    return (dec: _declination(l, 0), ra: _rightAscension(l, 0));
  }

  static ({double ra, double dec, double dist}) _moonCoords(double d) {
    final l = _rad * (218.316 + 13.176396 * d); // mittlere Länge
    final m = _rad * (134.963 + 13.064993 * d); // mittlere Anomalie
    final f = _rad * (93.272 + 13.229350 * d); // Breitenargument

    final lng = l + _rad * 6.289 * math.sin(m);
    final lat = _rad * 5.128 * math.sin(f);
    final dt = 385001 - 20905 * math.cos(m); // Entfernung in km

    return (ra: _rightAscension(lng, lat), dec: _declination(lng, lat), dist: dt);
  }

  // --- Sonnenstand jetzt ---

  /// Sonnenstand (Höhe + Azimut) zu einem konkreten Zeitpunkt.
  static SolarPosition sunPosition(DateTime date, double lat, double lng) {
    final lw = _rad * -lng;
    final phi = _rad * lat;
    final d = _toDays(date);
    final c = _sunCoords(d);
    final h = _siderealTime(d, lw) - c.ra;
    return SolarPosition(
      altitudeDeg: _altitude(h, phi, c.dec) / _rad,
      azimuthDeg: (_azimuth(h, phi, c.dec) / _rad + 180) % 360,
    );
  }

  /// Mondstand (Höhe + Azimut) zu einem konkreten Zeitpunkt.
  static SolarPosition moonPosition(DateTime date, double lat, double lng) {
    final lw = _rad * -lng;
    final phi = _rad * lat;
    final d = _toDays(date);
    final c = _moonCoords(d);
    final h = _siderealTime(d, lw) - c.ra;
    var alt = _altitude(h, phi, c.dec);

    // Refraktionskorrektur nahe am Horizont
    alt += _rad * 0.017 / math.tan(alt + _rad * 10.26 / (alt / _rad + 5.10));

    return SolarPosition(
      altitudeDeg: alt / _rad,
      azimuthDeg: (_azimuth(h, phi, c.dec) / _rad + 180) % 360,
    );
  }

  // --- Sonnenzeiten ---

  static const _j0 = 0.0009;

  static double _julianCycle(double d, double lw) => (d - _j0 - lw / (2 * math.pi)).roundToDouble();

  static double _approxTransit(double ht, double lw, double n) =>
      _j0 + (ht + lw) / (2 * math.pi) + n;

  static double _solarTransitJ(double ds, double m, double l) =>
      _j2000 + ds + 0.0053 * math.sin(m) - 0.0069 * math.sin(2 * l);

  static double _hourAngle(double h, double phi, double d) {
    final cosH = (math.sin(h) - math.sin(phi) * math.sin(d)) / (math.cos(phi) * math.cos(d));
    // |cosH| > 1 => Polartag oder Polarnacht: das Ereignis findet nicht statt.
    if (cosH > 1 || cosH < -1) return double.nan;
    return math.acos(cosH);
  }

  /// Berechnet alle Sonnen-Ereignisse des Tages, an dem [date] liegt.
  static SunTimes times(DateTime date, double lat, double lng) {
    final lw = _rad * -lng;
    final phi = _rad * lat;
    final d = _toDays(date);
    final n = _julianCycle(d, lw);
    final ds = _approxTransit(0, lw, n);
    final m = _solarMeanAnomaly(ds);
    final l = _eclipticLongitude(m);
    final dec = _declination(l, 0);
    final jNoon = _solarTransitJ(ds, m, l);

    /// Zeit, zu der die Sonne die Höhe [angleDeg] erreicht.
    /// [rising] = morgens (aufsteigend), sonst abends (absteigend).
    DateTime? at(double angleDeg, {required bool rising}) {
      final w = _hourAngle(_rad * angleDeg, phi, dec);
      if (w.isNaN) return null;
      final a = _approxTransit(w, lw, n);
      final jSet = _solarTransitJ(a, m, l);
      final j = rising ? jNoon - (jSet - jNoon) : jSet;
      return _fromJulian(j);
    }

    return SunTimes(
      solarNoon: _fromJulian(jNoon),
      nadir: _fromJulian(jNoon - 0.5),
      sunrise: at(-0.833, rising: true),
      sunset: at(-0.833, rising: false),
      // Golden Hour: Sonne zwischen -4° und +6°.
      goldenHourMorningStart: at(-4, rising: true),
      goldenHourMorningEnd: at(6, rising: true),
      goldenHourEveningStart: at(6, rising: false),
      goldenHourEveningEnd: at(-4, rising: false),
      // Blue Hour: Sonne zwischen -6° und -4°.
      blueHourMorningStart: at(-6, rising: true),
      blueHourMorningEnd: at(-4, rising: true),
      blueHourEveningStart: at(-4, rising: false),
      blueHourEveningEnd: at(-6, rising: false),
      // Astronomische Dämmerung: ab -18° ist der Himmel wirklich dunkel.
      astroDawn: at(-18, rising: true),
      astroDusk: at(-18, rising: false),
      polarDay: _hourAngle(_rad * -0.833, phi, dec).isNaN &&
          _altitude(0, phi, dec) / _rad > 0,
      polarNight: _hourAngle(_rad * -0.833, phi, dec).isNaN &&
          _altitude(0, phi, dec) / _rad <= 0,
    );
  }

  // --- Mond ---

  /// Mondphase + Beleuchtungsgrad.
  static MoonInfo moon(DateTime date, double lat, double lng) {
    final d = _toDays(date);
    final s = _sunCoords(d);
    final mo = _moonCoords(d);
    const sdist = 149598000.0; // mittlere Entfernung Erde–Sonne in km

    final phi = math.acos(math.sin(s.dec) * math.sin(mo.dec) +
        math.cos(s.dec) * math.cos(mo.dec) * math.cos(s.ra - mo.ra));
    final inc = math.atan2(sdist * math.sin(phi), mo.dist - sdist * math.cos(phi));
    final angle = math.atan2(
      math.cos(s.dec) * math.sin(s.ra - mo.ra),
      math.sin(s.dec) * math.cos(mo.dec) -
          math.cos(s.dec) * math.sin(mo.dec) * math.cos(s.ra - mo.ra),
    );

    final fraction = (1 + math.cos(inc)) / 2;
    final phase = 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / math.pi;

    final rs = _moonRiseSet(date, lat, lng);

    return MoonInfo(
      illumination: fraction,
      phase: phase,
      rise: rs.$1,
      setTime: rs.$2,
    );
  }

  /// Mondauf- und -untergang durch Abtasten der Höhe in 10-Minuten-Schritten.
  static (DateTime?, DateTime?) _moonRiseSet(DateTime date, double lat, double lng) {
    final start = DateTime.utc(date.toUtc().year, date.toUtc().month, date.toUtc().day);
    DateTime? rise;
    DateTime? setT;

    var prevAlt = moonPosition(start, lat, lng).altitudeDeg;
    for (var i = 10; i <= 24 * 60; i += 10) {
      final t = start.add(Duration(minutes: i));
      final alt = moonPosition(t, lat, lng).altitudeDeg;
      if (prevAlt < 0 && alt >= 0 && rise == null) {
        rise = t.subtract(const Duration(minutes: 5));
      }
      if (prevAlt >= 0 && alt < 0 && setT == null) {
        setT = t.subtract(const Duration(minutes: 5));
      }
      prevAlt = alt;
    }
    return (rise, setT);
  }

  /// Zeitzonen-Näherung über den Längengrad (keine IANA-Datenbank im MVP).
  /// Reicht, um Zeiten am Spot als grobe Ortszeit anzuzeigen.
  static Duration localOffsetFor(double lng) =>
      Duration(minutes: (lng / 15.0 * 60).round());

  /// Sichtbarkeit des Milchstraßen-Zentrums.
  ///
  /// Vereinfachtes Modell: das galaktische Zentrum steht auf der Nordhalbkugel
  /// etwa von Februar bis Oktober nachts über dem Horizont; entscheidend sind
  /// zusätzlich echte astronomische Dunkelheit und ein schwacher Mond.
  static MilkyWayInfo milkyWay(DateTime date, double lat, double lng) {
    final t = times(date, lat, lng);
    final m = moon(date, lat, lng);
    final month = date.month;

    final northern = lat >= 0;
    final coreSeason = northern
        ? (month >= 2 && month <= 10)
        : true; // Südhalbkugel: Kern fast ganzjährig, im Winter am besten

    final hasAstroDark = t.astroDusk != null && t.astroDawn != null;
    final moonOk = m.illumination < 0.35;

    final visible = coreSeason && hasAstroDark && moonOk;

    String reason;
    if (!coreSeason) {
      reason = 'Galaktisches Zentrum steht in dieser Jahreszeit nicht am Nachthimmel';
    } else if (!hasAstroDark) {
      reason = 'Keine astronomische Dunkelheit (zu weit nördlich/südlich in dieser Jahreszeit)';
    } else if (!moonOk) {
      reason = 'Mond zu hell (${(m.illumination * 100).round()}% beleuchtet)';
    } else {
      reason = 'Gute Bedingungen — dunkler Himmel und schwacher Mond';
    }

    return MilkyWayInfo(
      visible: visible,
      reason: reason,
      darkStart: t.astroDusk,
      darkEnd: t.astroDawn,
    );
  }
}

class SolarPosition {
  const SolarPosition({required this.altitudeDeg, required this.azimuthDeg});

  /// Höhe über dem Horizont in Grad (negativ = unter dem Horizont).
  final double altitudeDeg;

  /// Azimut in Grad, 0 = Nord, 90 = Ost, 180 = Süd, 270 = West.
  final double azimuthDeg;

  String get compass {
    const dirs = ['N', 'NNO', 'NO', 'ONO', 'O', 'OSO', 'SO', 'SSO',
                  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    return dirs[((azimuthDeg + 11.25) % 360 ~/ 22.5).toInt()];
  }
}

class SunTimes {
  const SunTimes({
    required this.solarNoon,
    required this.nadir,
    required this.sunrise,
    required this.sunset,
    required this.goldenHourMorningStart,
    required this.goldenHourMorningEnd,
    required this.goldenHourEveningStart,
    required this.goldenHourEveningEnd,
    required this.blueHourMorningStart,
    required this.blueHourMorningEnd,
    required this.blueHourEveningStart,
    required this.blueHourEveningEnd,
    required this.astroDawn,
    required this.astroDusk,
    required this.polarDay,
    required this.polarNight,
  });

  final DateTime solarNoon;
  final DateTime nadir;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? goldenHourMorningStart;
  final DateTime? goldenHourMorningEnd;
  final DateTime? goldenHourEveningStart;
  final DateTime? goldenHourEveningEnd;
  final DateTime? blueHourMorningStart;
  final DateTime? blueHourMorningEnd;
  final DateTime? blueHourEveningStart;
  final DateTime? blueHourEveningEnd;
  final DateTime? astroDawn;
  final DateTime? astroDusk;
  final bool polarDay;
  final bool polarNight;
}

class MoonInfo {
  const MoonInfo({
    required this.illumination,
    required this.phase,
    required this.rise,
    required this.setTime,
  });

  /// 0.0 = Neumond, 1.0 = Vollmond.
  final double illumination;

  /// 0 = Neumond, 0.25 = zunehmend halb, 0.5 = Vollmond, 0.75 = abnehmend halb.
  final double phase;

  final DateTime? rise;
  final DateTime? setTime;

  String get phaseLabel {
    if (phase < 0.03 || phase > 0.97) return 'Neumond';
    if (phase < 0.22) return 'zunehmende Sichel';
    if (phase < 0.28) return 'zunehmender Halbmond';
    if (phase < 0.47) return 'zunehmender Dreiviertelmond';
    if (phase < 0.53) return 'Vollmond';
    if (phase < 0.72) return 'abnehmender Dreiviertelmond';
    if (phase < 0.78) return 'abnehmender Halbmond';
    return 'abnehmende Sichel';
  }

  String get emoji {
    if (phase < 0.03 || phase > 0.97) return '🌑';
    if (phase < 0.22) return '🌒';
    if (phase < 0.28) return '🌓';
    if (phase < 0.47) return '🌔';
    if (phase < 0.53) return '🌕';
    if (phase < 0.72) return '🌖';
    if (phase < 0.78) return '🌗';
    return '🌘';
  }
}

class MilkyWayInfo {
  const MilkyWayInfo({
    required this.visible,
    required this.reason,
    required this.darkStart,
    required this.darkEnd,
  });

  final bool visible;
  final String reason;

  /// Beginn der astronomischen Dunkelheit (Sonne unter -18°).
  final DateTime? darkStart;
  final DateTime? darkEnd;
}
