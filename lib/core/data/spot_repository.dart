import '../models/filters.dart';
import '../models/spot.dart';

/// Eine Meldung zu einem Spot (Missbrauch, falscher Ort, Spam …).
class SpotReport {
  const SpotReport({
    required this.id,
    required this.spotId,
    required this.reason,
    required this.reporter,
    required this.createdAt,
  });

  final String id;
  final String spotId;
  final String reason;
  final String reporter;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'spotId': spotId,
        'reason': reason,
        'reporter': reporter,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SpotReport.fromJson(Map<String, dynamic> j) => SpotReport(
        id: j['id'] as String,
        spotId: j['spotId'] as String,
        reason: j['reason'] as String,
        reporter: j['reporter'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

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

  /// Löscht einen Spot. Nur der Autor oder der Owner dürfen das (in der UI geprüft).
  Future<void> delete(String spotId);

  Future<void> toggleLike(String spotId);
  Future<Set<String>> likedIds();

  Future<void> toggleSaved(String spotId);
  Future<Set<String>> savedIds();

  /// Spots, die der eingeloggte Nutzer selbst gepostet hat.
  Future<List<Spot>> mySpots();

  // --- Moderation ---

  /// Meldet einen Spot. Landet in der Owner-Übersicht.
  Future<void> report(String spotId, String reason, String reporter);

  /// Offene Meldungen (nur für den Owner relevant).
  Future<List<SpotReport>> openReports();

  /// Verwirft eine Meldung, ohne den Spot zu sperren.
  Future<void> dismissReport(String reportId);

  /// Sperrt oder entsperrt einen Spot. Gesperrte Spots verschwinden für alle
  /// außer dem Owner. Verwandte Meldungen werden dabei geschlossen.
  Future<void> setSpotBlocked(String spotId, bool blocked);
  Future<Set<String>> blockedSpotIds();

  /// Sperrt oder entsperrt einen Nutzer. Seine Spots verschwinden für alle außer
  /// dem Owner.
  Future<void> setUserBlocked(String userName, bool blocked);
  Future<Set<String>> blockedUserNames();
}
