import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../data/mock_spot_repository.dart';
import '../data/spot_repository.dart';
import '../data/supabase_spot_repository.dart';
import '../models/category.dart';
import '../models/filters.dart';
import '../models/spot.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';

/// Zentraler App-Zustand. Hält Spots, Filter, Likes, Speicherungen und PRO-Status.
class AppState extends ChangeNotifier {
  AppState._(this._repo, this._prefs);

  static const _kPro = 'is_pro';

  /// Free-Tier: bis zu 20 gespeicherte Orte (aus dem Konzept).
  static const freeSaveLimit = 20;

  final SpotRepository _repo;
  final SharedPreferences _prefs;
  final weather = WeatherService();

  List<Spot> _spots = [];
  Set<String> _liked = {};
  Set<String> _saved = {};
  SpotFilters _filters = const SpotFilters();
  bool _isPro = false;
  bool _loading = true;

  static Future<AppState> create() async {
    // Mit gültigen Zugangsdaten das echte Backend, sonst das Mock-Repository.
    // Fällt Supabase beim Start aus (Netz, falsche Keys), läuft die App trotzdem
    // im Mock-Modus weiter statt abzustürzen.
    SpotRepository repo;
    if (AppConfig.useSupabase) {
      try {
        repo = await SupabaseSpotRepository.connect(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
      } catch (e) {
        debugPrint('Supabase-Start fehlgeschlagen, nutze Mock: $e');
        repo = await MockSpotRepository.open();
      }
    } else {
      repo = await MockSpotRepository.open();
    }

    final prefs = await SharedPreferences.getInstance();
    final state = AppState._(repo, prefs);
    await state._load();
    return state;
  }

  Future<void> _load() async {
    _spots = await _repo.all();
    _liked = await _repo.likedIds();
    _saved = await _repo.savedIds();
    _isPro = _prefs.getBool(_kPro) ?? false;
    _loading = false;
    notifyListeners();
  }

  // --- Lesen ---

  bool get loading => _loading;
  bool get isPro => _isPro;
  List<Spot> get allSpots => _spots;
  SpotFilters get filters => _filters;
  Set<String> get savedIds => _saved;

  /// Die Spots, die aktuell auf der Karte und in der Liste erscheinen.
  List<Spot> get visibleSpots => _spots.where(_filters.matches).toList();

  List<Spot> get savedSpots => _spots.where((s) => _saved.contains(s.id)).toList();

  /// Anzeigename des aktuellen Nutzers — vom aktiven Repository (Mock oder Supabase).
  String get currentUserName => _repo.currentUserName;

  List<Spot> get mySpots =>
      _spots.where((s) => s.authorName == currentUserName).toList();

  /// Hidden Gems sind ein PRO-Feature — im Free-Tier bleiben sie verborgen.
  List<Spot> get hiddenGems =>
      isPro ? _spots.where((s) => s.isHiddenGem).toList() : const [];

  bool isLiked(String id) => _liked.contains(id);
  bool isSaved(String id) => _saved.contains(id);

  Spot? spotById(String id) {
    for (final s in _spots) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool get saveLimitReached => !isPro && _saved.length >= freeSaveLimit;

  // --- Schreiben ---

  Future<void> setFilters(SpotFilters filters) async {
    _filters = filters;
    notifyListeners();
  }

  Future<void> clearFilters() async {
    _filters = SpotFilters(center: _filters.center);
    notifyListeners();
  }

  LatLng? _userLocation;

  /// Zuletzt ermittelter Gerätestandort (für "in meiner Nähe" und die Karte).
  LatLng? get userLocation => _userLocation;

  Future<void> setUserLocation(LatLng center) async {
    _userLocation = center;
    _filters = _filters.copyWith(center: center);
    notifyListeners();
  }

  /// Holt den echten Gerätestandort und legt ihn als Filter-Zentrum ab.
  /// Gibt das Ergebnis zurück, damit die UI bei Ablehnung eine Meldung zeigen kann.
  Future<LocationResult> locateUser() async {
    final result = await LocationService.current();
    if (result.isSuccess) {
      await setUserLocation(result.position!);
    }
    return result;
  }

  Future<void> toggleLike(String id) async {
    await _repo.toggleLike(id);
    _spots = await _repo.all();
    _liked = await _repo.likedIds();
    notifyListeners();
  }

  /// Gibt false zurück, wenn das Free-Limit erreicht ist — die UI zeigt dann die Paywall.
  Future<bool> toggleSaved(String id) async {
    if (!_saved.contains(id) && saveLimitReached) return false;
    await _repo.toggleSaved(id);
    _saved = await _repo.savedIds();
    notifyListeners();
    return true;
  }

  Future<Spot> createSpot(Spot spot) async {
    final created = await _repo.create(spot);
    _spots = await _repo.all();
    notifyListeners();
    return created;
  }

  Future<void> setPro(bool value) async {
    _isPro = value;
    await _prefs.setBool(_kPro, value);
    notifyListeners();
  }

  // --- Gamification ---

  /// Likes, die auf die eigenen Spots eingegangen sind.
  int get likesReceived => mySpots.fold(0, (sum, s) => sum + s.likes);

  /// Länder, in denen der Nutzer Spots gepostet oder gespeichert hat.
  Set<String> get countriesVisited =>
      {...mySpots.map((s) => s.country), ...savedSpots.map((s) => s.country)};

  int get hikesLogged =>
      [...mySpots, ...savedSpots].where((s) => s.hikeMinutes > 0).length;

  int get sunrisesLogged => [...mySpots, ...savedSpots]
      .where((s) => s.category == SpotCategory.sunrise)
      .length;

  /// Erfahrungspunkte: posten zählt am meisten, dann erhaltene Likes, dann Reichweite.
  int get xp =>
      mySpots.length * 50 + likesReceived * 2 + countriesVisited.length * 100 + _saved.length * 10;

  int get level => (xp / 500).floor() + 1;

  double get levelProgress => (xp % 500) / 500.0;

  String get levelTitle => switch (level) {
        1 => 'Neuling',
        2 => 'Wanderer',
        3 => 'Entdecker',
        4 => 'Bergsteiger',
        5 => 'Kartograf',
        6 => 'Grenzgänger',
        _ => 'Legende',
      };

  List<AchievementBadge> get badges {
    final myAvgRating = mySpots.isEmpty
        ? 0.0
        : mySpots.fold(0.0, (sum, s) => sum + s.rating) / mySpots.length;

    return [
      AchievementBadge(
        emoji: '🥾',
        title: '100 Wanderungen',
        description: 'Sammle 100 Spots mit Wanderung',
        progress: hikesLogged,
        target: 100,
      ),
      AchievementBadge(
        emoji: '🌅',
        title: '50 Sonnenaufgänge',
        description: 'Sammle 50 Sonnenaufgangs-Spots',
        progress: sunrisesLogged,
        target: 50,
      ),
      AchievementBadge(
        emoji: '🌍',
        title: '10 Länder',
        description: 'Spots aus 10 verschiedenen Ländern',
        progress: countriesVisited.length,
        target: 10,
      ),
      AchievementBadge(
        emoji: '❤️',
        title: '100 Likes',
        description: 'Erhalte 100 Likes auf deine Spots',
        progress: likesReceived,
        target: 100,
      ),
      AchievementBadge(
        emoji: '📸',
        title: 'Top Fotograf',
        description: '5 eigene Spots mit ⌀ 4,8 Sternen',
        progress: mySpots.length >= 5 && myAvgRating >= 4.8 ? 1 : 0,
        target: 1,
      ),
    ];
  }
}

/// Heißt nicht `Badge` — das ist bereits ein Material-Widget.
class AchievementBadge {
  const AchievementBadge({
    required this.emoji,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
  });

  final String emoji;
  final String title;
  final String description;
  final int progress;
  final int target;

  bool get unlocked => progress >= target;
  double get fraction => (progress / target).clamp(0.0, 1.0);
}
