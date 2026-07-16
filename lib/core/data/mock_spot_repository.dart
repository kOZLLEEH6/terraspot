import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/filters.dart';
import '../models/spot.dart';
import 'mock_data.dart';
import 'spot_repository.dart';

/// In-Memory-Repository mit Persistenz über SharedPreferences.
///
/// Likes, gespeicherte Orte und selbst erstellte Spots überleben einen Neustart —
/// die 30 Basis-Spots kommen aus [buildMockSpots].
class MockSpotRepository implements SpotRepository {
  MockSpotRepository._(this._prefs, this._spots, this._liked, this._saved,
      this._blockedSpots, this._blockedUsers, this._reports);

  static const _kLiked = 'liked_ids';
  static const _kSaved = 'saved_ids';
  static const _kMySpots = 'my_spots';
  static const _kBlockedSpots = 'blocked_spots';
  static const _kBlockedUsers = 'blocked_users';
  static const _kReports = 'reports';

  /// Name des eingeloggten Nutzers im Mock. Seine Spots tauchen im Profil auf.
  static const defaultUserName = 'Alex Horst';

  @override
  String get currentUserName => defaultUserName;

  final SharedPreferences _prefs;
  final List<Spot> _spots;
  final Set<String> _liked;
  final Set<String> _saved;
  final Set<String> _blockedSpots;
  final Set<String> _blockedUsers;
  final List<SpotReport> _reports;

  /// Heißt bewusst nicht `create` — das ist schon die Methode zum Anlegen eines Spots.
  static Future<MockSpotRepository> open() async {
    final prefs = await SharedPreferences.getInstance();
    final spots = buildMockSpots();

    // Selbst erstellte Spots aus einer früheren Sitzung wieder einlesen.
    final raw = prefs.getStringList(_kMySpots) ?? const [];
    for (final s in raw) {
      try {
        spots.insert(0, Spot.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // Beschädigter Eintrag (z. B. nach einer Modelländerung) — überspringen.
      }
    }

    final reports = <SpotReport>[];
    for (final r in prefs.getStringList(_kReports) ?? const []) {
      try {
        reports.add(SpotReport.fromJson(jsonDecode(r) as Map<String, dynamic>));
      } catch (_) {}
    }

    return MockSpotRepository._(
      prefs,
      spots,
      (prefs.getStringList(_kLiked) ?? const []).toSet(),
      (prefs.getStringList(_kSaved) ?? const []).toSet(),
      (prefs.getStringList(_kBlockedSpots) ?? const []).toSet(),
      (prefs.getStringList(_kBlockedUsers) ?? const []).toSet(),
      reports,
    );
  }

  @override
  Future<List<Spot>> all() async => List.unmodifiable(_spots);

  @override
  Future<List<Spot>> search(SpotFilters filters) async =>
      _spots.where(filters.matches).toList();

  @override
  Future<Spot?> byId(String id) async {
    for (final s in _spots) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<Spot> create(Spot spot) async {
    _spots.insert(0, spot);
    await _persistMySpots();
    return spot;
  }

  @override
  Future<void> delete(String spotId) async {
    _spots.removeWhere((s) => s.id == spotId);
    _liked.remove(spotId);
    _saved.remove(spotId);
    _reports.removeWhere((r) => r.spotId == spotId);
    await _persistMySpots();
    await _prefs.setStringList(_kLiked, _liked.toList());
    await _prefs.setStringList(_kSaved, _saved.toList());
    await _persistReports();
  }

  Future<void> _persistMySpots() async {
    // Nur selbst erstellte Spots mit lokalem Foto überleben den Neustart.
    final mine = _spots
        .where((s) => s.authorName == defaultUserName && s.localPhotoPath != null)
        .map((s) => jsonEncode(s.toJson()))
        .toList();
    await _prefs.setStringList(_kMySpots, mine);
  }

  @override
  Future<void> toggleLike(String spotId) async {
    final index = _spots.indexWhere((s) => s.id == spotId);
    if (index == -1) return;

    final spot = _spots[index];
    if (_liked.contains(spotId)) {
      _liked.remove(spotId);
      _spots[index] = spot.copyWith(likes: spot.likes - 1);
    } else {
      _liked.add(spotId);
      _spots[index] = spot.copyWith(likes: spot.likes + 1);
    }
    await _prefs.setStringList(_kLiked, _liked.toList());
  }

  @override
  Future<Set<String>> likedIds() async => Set.of(_liked);

  @override
  Future<void> toggleSaved(String spotId) async {
    if (!_saved.remove(spotId)) _saved.add(spotId);
    await _prefs.setStringList(_kSaved, _saved.toList());
  }

  @override
  Future<Set<String>> savedIds() async => Set.of(_saved);

  @override
  Future<List<Spot>> mySpots() async =>
      _spots.where((s) => s.authorName == defaultUserName).toList();

  // --- Moderation ---

  @override
  Future<void> report(String spotId, String reason, String reporter) async {
    // Doppelmeldungen desselben Nutzers zum selben Spot vermeiden.
    if (_reports.any((r) => r.spotId == spotId && r.reporter == reporter)) return;
    _reports.add(SpotReport(
      id: 'r_${DateTime.now().microsecondsSinceEpoch}',
      spotId: spotId,
      reason: reason,
      reporter: reporter,
      createdAt: DateTime.now(),
    ));
    await _persistReports();
  }

  @override
  Future<List<SpotReport>> openReports() async => List.unmodifiable(_reports);

  @override
  Future<void> dismissReport(String reportId) async {
    _reports.removeWhere((r) => r.id == reportId);
    await _persistReports();
  }

  @override
  Future<void> setSpotBlocked(String spotId, bool blocked) async {
    if (blocked) {
      _blockedSpots.add(spotId);
      // Meldungen zu diesem Spot sind damit erledigt.
      _reports.removeWhere((r) => r.spotId == spotId);
      await _persistReports();
    } else {
      _blockedSpots.remove(spotId);
    }
    await _prefs.setStringList(_kBlockedSpots, _blockedSpots.toList());
  }

  @override
  Future<Set<String>> blockedSpotIds() async => Set.of(_blockedSpots);

  @override
  Future<void> setUserBlocked(String userName, bool blocked) async {
    if (blocked) {
      _blockedUsers.add(userName);
    } else {
      _blockedUsers.remove(userName);
    }
    await _prefs.setStringList(_kBlockedUsers, _blockedUsers.toList());
  }

  @override
  Future<Set<String>> blockedUserNames() async => Set.of(_blockedUsers);

  Future<void> _persistReports() async {
    await _prefs.setStringList(
      _kReports,
      _reports.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }
}
