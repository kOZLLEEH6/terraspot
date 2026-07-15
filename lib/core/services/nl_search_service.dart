import '../models/category.dart';
import '../models/filters.dart';

/// Übersetzt einen Satz in Filter.
///
/// "Ich möchte eine leichte Wanderung mit Wasserfall unter 5 km, Hunde erlaubt"
///   -> Kategorie Wasserfall + Wanderung, Schwierigkeit leicht, max. 5 km, Hunde erlaubt
///
/// Das ist bewusst ein regelbasierter Parser und kein LLM-Aufruf: er läuft offline,
/// kostet nichts, antwortet sofort und ist erklärbar — die App zeigt dem Nutzer,
/// was sie verstanden hat. Ein LLM würde hier später nur die Extraktion übernehmen
/// (gleicher Rückgabetyp), der Rest der App bliebe unverändert.
class NlSearchService {
  static const _categoryWords = <String, SpotCategory>{
    'sonnenaufgang': SpotCategory.sunrise,
    'sonnenaufgänge': SpotCategory.sunrise,
    'morgenrot': SpotCategory.sunrise,
    'aussicht': SpotCategory.viewpoint,
    'ausblick': SpotCategory.viewpoint,
    'panorama': SpotCategory.viewpoint,
    'sonnenuntergang': SpotCategory.viewpoint,
    'gipfel': SpotCategory.viewpoint,
    'nachthimmel': SpotCategory.nightSky,
    'sterne': SpotCategory.nightSky,
    'sternenhimmel': SpotCategory.nightSky,
    'milchstraße': SpotCategory.nightSky,
    'milchstrasse': SpotCategory.nightSky,
    'polarlicht': SpotCategory.nightSky,
    'nordlicht': SpotCategory.nightSky,
    'astro': SpotCategory.nightSky,
    'wandern': SpotCategory.hiking,
    'wanderung': SpotCategory.hiking,
    'wanderungen': SpotCategory.hiking,
    'tour': SpotCategory.hiking,
    'camping': SpotCategory.camping,
    'zelten': SpotCategory.camping,
    'zeltplatz': SpotCategory.camping,
    'blumen': SpotCategory.flowers,
    'lavendel': SpotCategory.flowers,
    'tulpen': SpotCategory.flowers,
    'blüte': SpotCategory.flowers,
    'herbst': SpotCategory.autumn,
    'laub': SpotCategory.autumn,
    'indian summer': SpotCategory.autumn,
    'winter': SpotCategory.winter,
    'schnee': SpotCategory.winter,
    'verschneit': SpotCategory.winter,
    'wasserfall': SpotCategory.waterfall,
    'wasserfälle': SpotCategory.waterfall,
    'kaskade': SpotCategory.waterfall,
    'strand': SpotCategory.beach,
    'meer': SpotCategory.beach,
    'küste': SpotCategory.beach,
    'bucht': SpotCategory.beach,
    'lagerfeuer': SpotCategory.campfire,
    'feuer': SpotCategory.campfire,
  };

  static const _difficultyWords = <String, Difficulty>{
    'leicht': Difficulty.easy,
    'leichte': Difficulty.easy,
    'einfach': Difficulty.easy,
    'einfache': Difficulty.easy,
    'gemütlich': Difficulty.easy,
    'mittel': Difficulty.medium,
    'mittlere': Difficulty.medium,
    'schwer': Difficulty.hard,
    'schwere': Difficulty.hard,
    'anspruchsvoll': Difficulty.hard,
    'anspruchsvolle': Difficulty.hard,
  };

  /// Zerlegt die Eingabe in Wörter. Umlaute und ß zählen als Buchstaben.
  static List<String> _tokenize(String q) => q
      .split(RegExp(r'[^a-zäöüß]+'))
      .where((w) => w.isNotEmpty)
      .toList();

  /// Prüft auf ein Schlüsselwort — an Wortgrenzen, nicht als Teilstring.
  ///
  /// Reine Teilstring-Suche wäre ein Minenfeld: "er**laub**t" enthält "laub"
  /// (Herbst), "**meer**" steckt in "Meerrettich". Deshalb muss ein Token mit dem
  /// Schlüsselwort *beginnen* — das fängt Beugungen wie "Wanderungen" mit ab,
  /// ohne mitten in fremden Wörtern zu treffen.
  static bool _hasWord(String key, List<String> tokens, String q) =>
      key.contains(' ') ? q.contains(key) : tokens.any((t) => t.startsWith(key));

  static NlSearchResult parse(String input, SpotFilters base) {
    final q = input.toLowerCase();
    final tokens = _tokenize(q);
    final understood = <String>[];

    var filters = SpotFilters(center: base.center);

    // Kategorien
    final cats = <SpotCategory>{};
    for (final entry in _categoryWords.entries) {
      if (_hasWord(entry.key, tokens, q)) cats.add(entry.value);
    }
    if (cats.isNotEmpty) {
      filters = filters.copyWith(categories: cats);
      understood.addAll(cats.map((c) => '${c.emoji} ${c.label}'));
    }

    // Schwierigkeit
    final diffs = <Difficulty>{};
    for (final entry in _difficultyWords.entries) {
      if (_hasWord(entry.key, tokens, q)) diffs.add(entry.value);
    }
    if (diffs.isNotEmpty) {
      filters = filters.copyWith(difficulties: diffs);
      understood.addAll(diffs.map((d) => '🥾 ${d.label}'));
    }

    // "unter 5 km", "weniger als 8 km", "max 3 km" -> Länge der Wanderung
    final hikeMatch = RegExp(
      r'(?:unter|weniger als|maximal|max\.?|bis zu|bis)\s+(\d+(?:[.,]\d+)?)\s*km',
    ).firstMatch(q);
    if (hikeMatch != null) {
      final km = double.parse(hikeMatch.group(1)!.replaceAll(',', '.'));
      filters = filters.copyWith(maxHikeKm: km);
      understood.add('📏 Wanderung unter $km km');
    }

    // "innerhalb 50 km", "in meiner nähe"
    final radiusMatch = RegExp(r'innerhalb\s+(?:von\s+)?(\d+)\s*km').firstMatch(q);
    if (radiusMatch != null) {
      filters = filters.copyWith(maxDistanceKm: double.parse(radiusMatch.group(1)!));
      understood.add('📍 Umkreis ${radiusMatch.group(1)} km');
    } else if (q.contains('in der nähe') || q.contains('in meiner nähe') || q.contains('nahe')) {
      filters = filters.copyWith(maxDistanceKm: 50);
      understood.add('📍 Umkreis 50 km');
    }

    // Ausstattung
    if (q.contains('hund')) {
      filters = filters.copyWith(dogsAllowed: true);
      understood.add('🐕 Hunde erlaubt');
    }
    if (q.contains('kind') || q.contains('familie')) {
      filters = filters.copyWith(kidsFriendly: true);
      understood.add('👶 Kindgeeignet');
    }
    if (q.contains('parkplatz') || q.contains('parken') || q.contains('auto')) {
      filters = filters.copyWith(hasParking: true);
      understood.add('🅿️ Parkplatz');
    }
    if (q.contains('übernachten') || q.contains('zelten') || q.contains('camping')) {
      filters = filters.copyWith(campingAllowed: true);
      understood.add('🏕️ Camping erlaubt');
    }

    // Saison
    if (q.contains('jetzt') || q.contains('gerade') || q.contains('aktuell') ||
        q.contains('dieses wochenende') || q.contains('diese woche')) {
      filters = filters.copyWith(onlyInSeason: true);
      understood.add('📅 Aktuell in Saison');
    }

    // Hidden Gems
    if (q.contains('geheim') || q.contains('unbekannt') || q.contains('wenig besucht') ||
        q.contains('nicht überlaufen') || q.contains('ruhig') || q.contains('einsam')) {
      filters = filters.copyWith(onlyHiddenGems: true);
      understood.add('💎 Hidden Gems');
    }

    // Was übrig bleibt, wird als Freitext gegen Titel/Land/Region gesucht.
    final leftover = _leftoverTerms(q);
    if (leftover != null) {
      filters = filters.copyWith(query: leftover);
      understood.add('🔎 "$leftover"');
    }

    return NlSearchResult(filters: filters, understood: understood);
  }

  /// Sucht nach einem Eigennamen (Land, Region, Berg), der nicht schon als
  /// Filter erkannt wurde. Stoppwörter und alle bekannten Schlüsselwörter fliegen raus.
  static String? _leftoverTerms(String q) {
    const stop = {
      'ich', 'möchte', 'will', 'suche', 'einen', 'eine', 'ein', 'mit', 'und', 'oder',
      'für', 'der', 'die', 'das', 'den', 'dem', 'am', 'im', 'in', 'auf', 'zu', 'nach',
      'von', 'bei', 'ist', 'sind', 'nur', 'auch', 'noch', 'mal', 'bitte', 'gerne',
      'erlaubt', 'geeignet', 'km', 'unter', 'über', 'weniger', 'als', 'maximal', 'max',
      'bis', 'innerhalb', 'nähe', 'meiner', 'der nähe', 'spots', 'spot', 'orte', 'ort',
      'schöne', 'schön', 'gute', 'gut', 'beste', 'besten', 'wo', 'was', 'wie', 'wann',
    };

    final words = q
        .replaceAll(RegExp(r'[^\wäöüß\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .where((w) => !stop.contains(w))
        .where((w) => !_categoryWords.containsKey(w))
        .where((w) => !_difficultyWords.containsKey(w))
        .where((w) => !RegExp(r'^\d+$').hasMatch(w))
        .where((w) => !['hund', 'hunde', 'kinder', 'kind', 'familie', 'parkplatz',
                        'parken', 'auto', 'übernachten', 'jetzt', 'geheim', 'ruhig',
                        'einsam', 'unbekannt', 'besucht', 'überlaufen'].contains(w))
        .toList();

    return words.isEmpty ? null : words.join(' ');
  }
}

class NlSearchResult {
  const NlSearchResult({required this.filters, required this.understood});

  final SpotFilters filters;

  /// Was der Parser verstanden hat — wird dem Nutzer als Chips gezeigt,
  /// damit er die Interpretation korrigieren kann.
  final List<String> understood;
}
