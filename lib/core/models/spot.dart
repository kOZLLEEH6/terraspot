import 'package:latlong2/latlong.dart';

import 'category.dart';

/// Ein Spot ist ein vollständiger Outdoor-Guide, nicht nur ein Foto.
class Spot {
  const Spot({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.lat,
    required this.lng,
    required this.country,
    required this.region,
    required this.photoUrls,
    required this.rating,
    required this.ratingCount,
    required this.bestTimeOfDay,
    required this.bestMonths,
    required this.difficulty,
    required this.hikeMinutes,
    required this.hikeKm,
    required this.elevationM,
    required this.hasParking,
    required this.dogsAllowed,
    required this.kidsFriendly,
    required this.campingAllowed,
    required this.likes,
    required this.authorName,
    required this.createdAt,
    required this.visitorsPerDay,
    this.localPhotoPath,
  });

  final String id;
  final String title;
  final String description;
  final SpotCategory category;
  final double lat;
  final double lng;
  final String country;
  final String region;

  /// Netzwerk-Fotos (Wikimedia). Erstes Bild ist das Titelbild.
  final List<String> photoUrls;

  /// Wird nur bei selbst erstellten Spots gesetzt (Datei bzw. Blob-URL im Web).
  final String? localPhotoPath;

  final double rating;
  final int ratingCount;

  /// Beste Uhrzeit als "HH:mm" — der vom Ersteller angegebene Referenzwert.
  final String bestTimeOfDay;

  /// Monate 1-12, in denen der Spot am besten ist.
  final List<int> bestMonths;

  final Difficulty difficulty;
  final int hikeMinutes;
  final double hikeKm;
  final int elevationM;

  final bool hasParking;
  final bool dogsAllowed;
  final bool kidsFriendly;
  final bool campingAllowed;

  final int likes;
  final String authorName;
  final DateTime createdAt;

  /// Grundlage für Crowd-Prediction und Hidden-Gems.
  final int visitorsPerDay;

  LatLng get position => LatLng(lat, lng);

  /// Hidden Gem: wenig besucht, aber hoch bewertet. Die Schwelle liegt bei
  /// 400 Besuchern/Tag — gemessen an den beliebten Spots (2.000–5.000/Tag) ist
  /// das wirklich einsam, aber nicht so streng, dass die Liste leer bliebe.
  bool get isHiddenGem => visitorsPerDay < 400 && rating >= 4.5;

  bool get isInSeason => bestMonths.contains(DateTime.now().month);

  String get seasonLabel {
    if (bestMonths.isEmpty) return 'ganzjährig';
    const names = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
    ];
    final sorted = [...bestMonths]..sort();
    if (sorted.length >= 11) return 'ganzjährig';

    // Zusammenhängende Bereiche (auch über den Jahreswechsel) als "Mai–Sep" ausgeben.
    final ranges = <String>[];
    var start = sorted.first;
    var prev = sorted.first;
    for (final m in sorted.skip(1)) {
      if (m == prev + 1) {
        prev = m;
      } else {
        ranges.add(start == prev ? names[start - 1] : '${names[start - 1]}–${names[prev - 1]}');
        start = m;
        prev = m;
      }
    }
    ranges.add(start == prev ? names[start - 1] : '${names[start - 1]}–${names[prev - 1]}');
    return ranges.join(', ');
  }

  String get hikeLabel {
    if (hikeMinutes == 0) return 'direkt am Parkplatz';
    final h = hikeMinutes ~/ 60;
    final m = hikeMinutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  Spot copyWith({int? likes}) => Spot(
        id: id,
        title: title,
        description: description,
        category: category,
        lat: lat,
        lng: lng,
        country: country,
        region: region,
        photoUrls: photoUrls,
        localPhotoPath: localPhotoPath,
        rating: rating,
        ratingCount: ratingCount,
        bestTimeOfDay: bestTimeOfDay,
        bestMonths: bestMonths,
        difficulty: difficulty,
        hikeMinutes: hikeMinutes,
        hikeKm: hikeKm,
        elevationM: elevationM,
        hasParking: hasParking,
        dogsAllowed: dogsAllowed,
        kidsFriendly: kidsFriendly,
        campingAllowed: campingAllowed,
        likes: likes ?? this.likes,
        authorName: authorName,
        createdAt: createdAt,
        visitorsPerDay: visitorsPerDay,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'lat': lat,
        'lng': lng,
        'country': country,
        'region': region,
        'photoUrls': photoUrls,
        'localPhotoPath': localPhotoPath,
        'rating': rating,
        'ratingCount': ratingCount,
        'bestTimeOfDay': bestTimeOfDay,
        'bestMonths': bestMonths,
        'difficulty': difficulty.name,
        'hikeMinutes': hikeMinutes,
        'hikeKm': hikeKm,
        'elevationM': elevationM,
        'hasParking': hasParking,
        'dogsAllowed': dogsAllowed,
        'kidsFriendly': kidsFriendly,
        'campingAllowed': campingAllowed,
        'likes': likes,
        'authorName': authorName,
        'createdAt': createdAt.toIso8601String(),
        'visitorsPerDay': visitorsPerDay,
      };

  factory Spot.fromJson(Map<String, dynamic> j) => Spot(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        category: SpotCategory.fromName(j['category'] as String),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        country: j['country'] as String,
        region: j['region'] as String,
        photoUrls: (j['photoUrls'] as List).cast<String>(),
        localPhotoPath: j['localPhotoPath'] as String?,
        rating: (j['rating'] as num).toDouble(),
        ratingCount: j['ratingCount'] as int,
        bestTimeOfDay: j['bestTimeOfDay'] as String,
        bestMonths: (j['bestMonths'] as List).cast<int>(),
        difficulty: Difficulty.fromName(j['difficulty'] as String),
        hikeMinutes: j['hikeMinutes'] as int,
        hikeKm: (j['hikeKm'] as num).toDouble(),
        elevationM: j['elevationM'] as int,
        hasParking: j['hasParking'] as bool,
        dogsAllowed: j['dogsAllowed'] as bool,
        kidsFriendly: j['kidsFriendly'] as bool,
        campingAllowed: j['campingAllowed'] as bool,
        likes: j['likes'] as int,
        authorName: j['authorName'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        visitorsPerDay: j['visitorsPerDay'] as int,
      );
}
