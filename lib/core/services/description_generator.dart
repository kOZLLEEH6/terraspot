import '../models/category.dart';

/// Erzeugt aus den Formularfeldern eine natürliche Ortsbeschreibung.
///
/// Regelbasiert und offline — kein LLM/Backend nötig. Die Formulierung richtet
/// sich nach der Kategorie und den ausgefüllten Feldern. Später kann hier ein
/// echter KI-Text (Anthropic/OpenAI) eingehängt werden; die Signatur bleibt gleich.
class DescriptionGenerator {
  static String generate({
    required String title,
    required SpotCategory category,
    required String region,
    required String country,
    required String bestTimeOfDay,
    required Set<int> bestMonths,
    required Difficulty difficulty,
    required int hikeMinutes,
    required double hikeKm,
    required int elevationM,
    required bool hasParking,
    required bool dogsAllowed,
    required bool kidsFriendly,
    required bool campingAllowed,
  }) {
    final name = title.trim().isEmpty ? 'Dieser Spot' : title.trim();
    final where = _where(region, country);

    final parts = <String>[
      _hook(name, category, where),
      _timing(category, bestTimeOfDay, bestMonths),
      _access(difficulty, hikeMinutes, hikeKm, elevationM, hasParking),
      _amenities(dogsAllowed, kidsFriendly, campingAllowed),
    ];

    return parts.where((s) => s.isNotEmpty).join(' ');
  }

  static String _where(String region, String country) {
    final r = region.trim();
    final c = country.trim();
    if (r.isNotEmpty && c.isNotEmpty) return ' in $r, $c';
    if (c.isNotEmpty) return ' in $c';
    if (r.isNotEmpty) return ' in $r';
    return '';
  }

  static String _hook(String name, SpotCategory category, String where) {
    switch (category) {
      case SpotCategory.sunrise:
        return '$name$where ist ein Ort für den Sonnenaufgang — wenn das erste '
            'Licht die Landschaft in warme Farben taucht, lohnt sich das frühe Aufstehen.';
      case SpotCategory.viewpoint:
        return '$name$where belohnt dich mit einem weiten Ausblick über die Umgebung.';
      case SpotCategory.nightSky:
        return 'Über $name$where spannt sich ein dunkler Nachthimmel — ideal für '
            'Sterne, Milchstraße und lange Belichtungen.';
      case SpotCategory.hiking:
        return '$name$where ist ein lohnendes Wanderziel abseits des Trubels.';
      case SpotCategory.camping:
        return '$name$where ist ein schöner Platz, um unter freiem Himmel zu '
            'übernachten.';
      case SpotCategory.flowers:
        return '$name$where zeigt sich zur Blütezeit von seiner schönsten Seite.';
      case SpotCategory.autumn:
        return 'Im Herbst färbt sich $name$where in warme, leuchtende Töne.';
      case SpotCategory.winter:
        return 'Im Winter liegt $name$where verschneit und still da.';
      case SpotCategory.waterfall:
        return '$name$where ist ein eindrucksvoller Wasserfall — am schönsten '
            'nach ergiebigem Regen.';
      case SpotCategory.beach:
        return '$name$where lädt mit Küste und Meer zum Verweilen ein.';
      case SpotCategory.campfire:
        return '$name$where eignet sich für einen ruhigen Abend am Lagerfeuer.';
    }
  }

  static String _timing(
      SpotCategory category, String bestTime, Set<int> months) {
    final bits = <String>[];
    if (bestTime.trim().isNotEmpty) {
      bits.add('Die beste Uhrzeit ist gegen $bestTime Uhr');
    }
    final season = _season(months);
    if (season.isNotEmpty) {
      bits.add(bits.isEmpty
          ? 'Am schönsten ist es $season'
          : ', und am schönsten ist es $season');
    }
    if (bits.isEmpty) return '';
    return '${bits.join()}.'.replaceAll(' ,', ',');
  }

  static String _access(Difficulty difficulty, int hikeMinutes, double hikeKm,
      int elevationM, bool hasParking) {
    if (hikeMinutes <= 0) {
      return hasParking
          ? 'Der Ort liegt praktisch direkt am Parkplatz — kein langer Fußweg nötig.'
          : 'Der Ort ist ohne nennenswerten Fußweg erreichbar.';
    }
    final h = hikeMinutes ~/ 60;
    final m = hikeMinutes % 60;
    final dur = h == 0 ? '$m Minuten' : (m == 0 ? '$h Stunden' : '$h Std. $m Min.');
    final km = hikeKm > 0 ? ' (${hikeKm.toStringAsFixed(1)} km)' : '';
    final diff = switch (difficulty) {
      Difficulty.easy => 'leicht',
      Difficulty.medium => 'mittelschwer',
      Difficulty.hard => 'anspruchsvoll',
    };
    final park = hasParking ? ' Am Ausgangspunkt gibt es Parkplätze.' : '';
    return 'Der Weg dorthin ist $diff und dauert etwa $dur$km.$park';
  }

  static String _amenities(bool dogs, bool kids, bool camping) {
    final ok = <String>[];
    if (dogs) ok.add('Hunde sind erlaubt');
    if (kids) ok.add('der Ort ist auch für Kinder geeignet');
    if (camping) ok.add('Übernachten ist gestattet');
    if (ok.isEmpty) return '';
    final joined = ok.length == 1
        ? ok.first
        : '${ok.take(ok.length - 1).join(', ')} und ${ok.last}';
    return '${joined[0].toUpperCase()}${joined.substring(1)}.';
  }

  static String _season(Set<int> months) {
    if (months.isEmpty || months.length >= 11) return '';
    const names = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    final sorted = months.toList()..sort();
    // Zusammenhängende Bereiche als „von Mai bis September" ausgeben.
    final ranges = <String>[];
    var start = sorted.first;
    var prev = sorted.first;
    for (final mo in sorted.skip(1)) {
      if (mo == prev + 1) {
        prev = mo;
      } else {
        ranges.add(start == prev
            ? 'im ${names[start - 1]}'
            : 'von ${names[start - 1]} bis ${names[prev - 1]}');
        start = mo;
        prev = mo;
      }
    }
    ranges.add(start == prev
        ? 'im ${names[start - 1]}'
        : 'von ${names[start - 1]} bis ${names[prev - 1]}');
    return ranges.join(' und ');
  }
}
