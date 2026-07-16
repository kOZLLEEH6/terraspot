import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../models/filters.dart';
import '../models/spot.dart';
import 'spot_repository.dart';

/// Echte Datenquelle: Supabase (Postgres + Auth + Storage).
///
/// Implementiert exakt dasselbe [SpotRepository] wie das Mock — die UI merkt vom
/// Wechsel nichts. Für den MVP wird ein anonymer Auth-Nutzer verwendet, damit
/// Liken, Speichern und Erstellen ohne Registrierungsformular funktionieren.
class SupabaseSpotRepository implements SpotRepository {
  SupabaseSpotRepository._(this._client, this._userId, this._userName);

  final SupabaseClient _client;
  final String _userId;
  final String _userName;

  /// Heißt nicht `create` — das ist schon die Methode zum Anlegen eines Spots.
  static Future<SupabaseSpotRepository> connect({
    required String url,
    required String anonKey,
  }) async {
    // anonKey ist in neueren SDKs zugunsten von publishableKey als „deprecated"
    // markiert, funktioniert aber weiter und ist der Schlüssel, den das
    // Supabase-Dashboard prominent anzeigt.
    // ignore: deprecated_member_use
    await Supabase.initialize(url: url, anonKey: anonKey);
    final client = Supabase.instance.client;

    // Anonyme Session, falls noch keine besteht.
    var user = client.auth.currentUser;
    if (user == null) {
      final res = await client.auth.signInAnonymously();
      user = res.user;
    }
    if (user == null) {
      throw StateError('Supabase-Anmeldung fehlgeschlagen');
    }

    // Anzeigename aus dem Profil (vom Trigger angelegt), sonst Fallback.
    String name = 'Entdecker';
    try {
      final profile = await client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null && profile['display_name'] != null) {
        name = profile['display_name'] as String;
      }
    } catch (_) {
      // Profil noch nicht da (Trigger-Latenz) — Fallback reicht.
    }

    return SupabaseSpotRepository._(client, user.id, name);
  }

  @override
  String get currentUserName => _userName;

  // --- Mapping DB-Zeile <-> Spot ---

  Spot _fromRow(Map<String, dynamic> r, {int likes = 0}) => Spot(
        id: r['id'] as String,
        title: r['title'] as String,
        description: r['description'] as String,
        category: SpotCategory.fromName(r['category'] as String),
        lat: (r['lat'] as num).toDouble(),
        lng: (r['lng'] as num).toDouble(),
        country: r['country'] as String,
        region: r['region'] as String,
        photoUrls: (r['photo_urls'] as List?)?.cast<String>() ?? const [],
        rating: (r['rating'] as num?)?.toDouble() ?? 0,
        ratingCount: (r['rating_count'] as int?) ?? 0,
        bestTimeOfDay: r['best_time_of_day'] as String,
        bestMonths: (r['best_months'] as List?)?.cast<int>() ?? const [],
        difficulty: Difficulty.fromName(r['difficulty'] as String),
        hikeMinutes: (r['hike_minutes'] as int?) ?? 0,
        hikeKm: (r['hike_km'] as num?)?.toDouble() ?? 0,
        elevationM: (r['elevation_m'] as int?) ?? 0,
        hasParking: (r['has_parking'] as bool?) ?? false,
        dogsAllowed: (r['dogs_allowed'] as bool?) ?? false,
        kidsFriendly: (r['kids_friendly'] as bool?) ?? false,
        campingAllowed: (r['camping_allowed'] as bool?) ?? false,
        likes: likes,
        authorName: r['author_name'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        visitorsPerDay: (r['visitors_per_day'] as int?) ?? 0,
      );

  Future<Map<String, int>> _likeCounts() async {
    final rows = await _client.from('spot_like_counts').select('spot_id, likes');
    return {
      for (final r in rows as List) r['spot_id'] as String: r['likes'] as int,
    };
  }

  // --- Lesen ---

  @override
  Future<List<Spot>> all() async {
    final rows = await _client.from('spots').select().order('created_at', ascending: false);
    final counts = await _likeCounts();
    return [
      for (final r in rows as List)
        _fromRow(r as Map<String, dynamic>, likes: counts[r['id']] ?? 0),
    ];
  }

  @override
  Future<List<Spot>> search(SpotFilters filters) async {
    // Grobfilter in der DB (Kategorie), Feinfilter clientseitig über dieselbe
    // matches()-Logik wie beim Mock — so bleibt das Verhalten identisch.
    final all = await this.all();
    return all.where(filters.matches).toList();
  }

  @override
  Future<Spot?> byId(String id) async {
    final r = await _client.from('spots').select().eq('id', id).maybeSingle();
    if (r == null) return null;
    final counts = await _likeCounts();
    return _fromRow(r, likes: counts[id] ?? 0);
  }

  @override
  Future<Spot> create(Spot spot) async {
    // Falls ein lokales Foto vorliegt, zuerst in den Storage hochladen.
    final photoUrls = <String>[];
    if (spot.localPhotoPath != null && !kIsWeb) {
      final path = 'user/$_userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('spot-photos').upload(path, File(spot.localPhotoPath!));
      photoUrls.add(_client.storage.from('spot-photos').getPublicUrl(path));
    } else {
      photoUrls.addAll(spot.photoUrls);
    }

    final inserted = await _client
        .from('spots')
        .insert({
          'author_id': _userId,
          'author_name': _userName,
          'title': spot.title,
          'description': spot.description,
          'category': spot.category.name,
          'lat': spot.lat,
          'lng': spot.lng,
          'country': spot.country,
          'region': spot.region,
          'photo_urls': photoUrls,
          'best_time_of_day': spot.bestTimeOfDay,
          'best_months': spot.bestMonths,
          'difficulty': spot.difficulty.name,
          'hike_minutes': spot.hikeMinutes,
          'hike_km': spot.hikeKm,
          'elevation_m': spot.elevationM,
          'has_parking': spot.hasParking,
          'dogs_allowed': spot.dogsAllowed,
          'kids_friendly': spot.kidsFriendly,
          'camping_allowed': spot.campingAllowed,
          'visitors_per_day': spot.visitorsPerDay,
        })
        .select()
        .single();

    return _fromRow(inserted);
  }

  @override
  Future<void> delete(String spotId) async {
    // RLS lässt nur den Autor löschen (siehe 002_rls.sql).
    await _client.from('spots').delete().eq('id', spotId);
  }

  // --- Moderation ---
  // Für den MVP schlank gehalten: Meldungen landen in einer Tabelle `reports`,
  // die eigentliche Owner-Moderation (Sperren) läuft aktuell nur im Mock-Modus.
  // Beim Aktivieren von Supabase kommen dafür Admin-Policies + eine `blocks`-Tabelle
  // dazu — die Signaturen hier bleiben gleich.

  @override
  Future<void> report(String spotId, String reason, String reporter) async {
    await _client.from('reports').insert({
      'spot_id': spotId,
      'reason': reason,
      'reporter': reporter,
    });
  }

  @override
  Future<List<SpotReport>> openReports() async => const [];

  @override
  Future<void> dismissReport(String reportId) async {}

  @override
  Future<void> setSpotBlocked(String spotId, bool blocked) async {}

  @override
  Future<Set<String>> blockedSpotIds() async => const {};

  @override
  Future<void> setUserBlocked(String userName, bool blocked) async {}

  @override
  Future<Set<String>> blockedUserNames() async => const {};

  // --- Likes ---

  @override
  Future<void> toggleLike(String spotId) async {
    final existing = await _client
        .from('likes')
        .select()
        .eq('user_id', _userId)
        .eq('spot_id', spotId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('likes').insert({'user_id': _userId, 'spot_id': spotId});
    } else {
      await _client.from('likes').delete().eq('user_id', _userId).eq('spot_id', spotId);
    }
  }

  @override
  Future<Set<String>> likedIds() async {
    final rows = await _client.from('likes').select('spot_id').eq('user_id', _userId);
    return {for (final r in rows as List) r['spot_id'] as String};
  }

  // --- Saves ---

  @override
  Future<void> toggleSaved(String spotId) async {
    final existing = await _client
        .from('saves')
        .select()
        .eq('user_id', _userId)
        .eq('spot_id', spotId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('saves').insert({'user_id': _userId, 'spot_id': spotId});
    } else {
      await _client.from('saves').delete().eq('user_id', _userId).eq('spot_id', spotId);
    }
  }

  @override
  Future<Set<String>> savedIds() async {
    final rows = await _client.from('saves').select('spot_id').eq('user_id', _userId);
    return {for (final r in rows as List) r['spot_id'] as String};
  }

  @override
  Future<List<Spot>> mySpots() async {
    final rows = await _client
        .from('spots')
        .select()
        .eq('author_id', _userId)
        .order('created_at', ascending: false);
    final counts = await _likeCounts();
    return [
      for (final r in rows as List)
        _fromRow(r as Map<String, dynamic>, likes: counts[r['id']] ?? 0),
    ];
  }
}
