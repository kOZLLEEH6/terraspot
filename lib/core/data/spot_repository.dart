import '../models/filters.dart';
import '../models/spot.dart';

/// Die einzige Naht zwischen UI und Datenquelle.
///
/// Heute: [MockSpotRepository] (In-Memory + SharedPreferences).
/// Später: `SupabaseSpotRepository` — gleiche Signaturen, die UI merkt nichts davon.
abstract class SpotRepository {
  /// Anzeigename des aktuell angemeldeten Nutzers. Beim Mock fest, bei Supabase
  /// aus dem Profil der (anonymen) Session.
  String get currentUserName;

  Future<List<Spot>> all();

  Future<List<Spot>> search(SpotFilters filters);

  Future<Spot?> byId(String id);

  /// Legt einen neuen Spot an und gibt ihn mit vergebener ID zurück.
  Future<Spot> create(Spot spot);

  Future<void> toggleLike(String spotId);
  Future<Set<String>> likedIds();

  Future<void> toggleSaved(String spotId);
  Future<Set<String>> savedIds();

  /// Spots, die der eingeloggte Nutzer selbst gepostet hat.
  Future<List<Spot>> mySpots();
}
