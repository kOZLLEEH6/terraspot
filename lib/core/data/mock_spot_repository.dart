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
  MockSpotRepository._(this._prefs, this._spots, this._liked, this._saved);

  static const _kLiked = 'liked_ids';
  static const _kSaved = 'saved_ids';
  static const _kMySpots = 'my_spots';

  /// Name des eingeloggten Nutzers im Mock. Seine Spots tauchen im Profil auf.
  static const defaultUserName = 'Alex Horst';

  @override
  String get currentUserName => defaultUserName;

  final SharedPreferences _prefs;
  final List<Spot> _spots;
  final Set<String> _liked;
  final Set<String> _saved;

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

    return MockSpotRepository._(
      prefs,
      spots,
      (prefs.getStringList(_kLiked) ?? const []).toSet(),
      (prefs.getStringList(_kSaved) ?? const []).toSet(),
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
    final mine = _spots
        .where((s) => s.authorName == defaultUserName && s.localPhotoPath != null)
        .map((s) => jsonEncode(s.toJson()))
        .toList();
    await _prefs.setStringList(_kMySpots, mine);
    return spot;
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
}
