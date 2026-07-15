import 'package:latlong2/latlong.dart';

import 'category.dart';
import 'spot.dart';

/// Filter aus dem Konzept: Kategorien, Schwierigkeit, Umkreis, Saison, Ausstattung.
class SpotFilters {
  const SpotFilters({
    this.query = '',
    this.categories = const {},
    this.difficulties = const {},
    this.maxDistanceKm,
    this.maxHikeKm,
    this.onlyInSeason = false,
    this.onlyHiddenGems = false,
    this.dogsAllowed = false,
    this.kidsFriendly = false,
    this.hasParking = false,
    this.campingAllowed = false,
    this.center,
  });

  final String query;
  final Set<SpotCategory> categories;
  final Set<Difficulty> difficulties;

  /// "Nur innerhalb 50 km" — Umkreis um [center].
  final double? maxDistanceKm;

  /// "Unter 5 km" — Länge der Wanderung selbst.
  final double? maxHikeKm;

  final bool onlyInSeason;
  final bool onlyHiddenGems;
  final bool dogsAllowed;
  final bool kidsFriendly;
  final bool hasParking;
  final bool campingAllowed;
  final LatLng? center;

  bool get isEmpty =>
      query.isEmpty &&
      categories.isEmpty &&
      difficulties.isEmpty &&
      maxDistanceKm == null &&
      maxHikeKm == null &&
      !onlyInSeason &&
      !onlyHiddenGems &&
      !dogsAllowed &&
      !kidsFriendly &&
      !hasParking &&
      !campingAllowed;

  int get activeCount => [
        categories.isNotEmpty,
        difficulties.isNotEmpty,
        maxDistanceKm != null,
        maxHikeKm != null,
        onlyInSeason,
        onlyHiddenGems,
        dogsAllowed,
        kidsFriendly,
        hasParking,
        campingAllowed,
      ].where((e) => e).length;

  SpotFilters copyWith({
    String? query,
    Set<SpotCategory>? categories,
    Set<Difficulty>? difficulties,
    double? maxDistanceKm,
    double? maxHikeKm,
    bool? onlyInSeason,
    bool? onlyHiddenGems,
    bool? dogsAllowed,
    bool? kidsFriendly,
    bool? hasParking,
    bool? campingAllowed,
    LatLng? center,
    bool clearMaxDistance = false,
    bool clearMaxHike = false,
  }) =>
      SpotFilters(
        query: query ?? this.query,
        categories: categories ?? this.categories,
        difficulties: difficulties ?? this.difficulties,
        maxDistanceKm: clearMaxDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
        maxHikeKm: clearMaxHike ? null : (maxHikeKm ?? this.maxHikeKm),
        onlyInSeason: onlyInSeason ?? this.onlyInSeason,
        onlyHiddenGems: onlyHiddenGems ?? this.onlyHiddenGems,
        dogsAllowed: dogsAllowed ?? this.dogsAllowed,
        kidsFriendly: kidsFriendly ?? this.kidsFriendly,
        hasParking: hasParking ?? this.hasParking,
        campingAllowed: campingAllowed ?? this.campingAllowed,
        center: center ?? this.center,
      );

  bool matches(Spot spot) {
    if (categories.isNotEmpty && !categories.contains(spot.category)) return false;
    if (difficulties.isNotEmpty && !difficulties.contains(spot.difficulty)) return false;
    if (maxHikeKm != null && spot.hikeKm > maxHikeKm!) return false;
    if (onlyInSeason && !spot.isInSeason) return false;
    if (onlyHiddenGems && !spot.isHiddenGem) return false;
    if (dogsAllowed && !spot.dogsAllowed) return false;
    if (kidsFriendly && !spot.kidsFriendly) return false;
    if (hasParking && !spot.hasParking) return false;
    if (campingAllowed && !spot.campingAllowed) return false;

    if (maxDistanceKm != null && center != null) {
      final km = const Distance().as(LengthUnit.Kilometer, center!, spot.position);
      if (km > maxDistanceKm!) return false;
    }

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final haystack =
          '${spot.title} ${spot.description} ${spot.country} ${spot.region} '
                  '${spot.category.label}'
              .toLowerCase();
      if (!haystack.contains(q)) return false;
    }
    return true;
  }
}
