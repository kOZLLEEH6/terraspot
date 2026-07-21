import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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
import '../services/billing_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';

/// Zentraler App-Zustand. Hält Spots, Filter, Likes, Speicherungen und PRO-Status.
class AppState extends ChangeNotifier {
  AppState._(this._repo, this._prefs);

  static const _kProUntil = 'pro_until';
  static const _kAutoRenew = 'pro_auto_renew';
  static const _kGiftCodes = 'gift_codes';
  static const _kTermsVersion = 'accepted_terms_version';
  static const _kTermsAcceptedAt = 'accepted_terms_at';
  static const _kAccUsername = 'account_username';
  static const _kAccPassHash = 'account_pass_hash';
  static const _kAccSalt = 'account_salt';
  static const _kSignedIn = 'account_signed_in';
  static const _kAccIsOwner = 'account_is_owner';

  /// Version der akzeptierten Bedingungen. Erhöhen, wenn sich die AGB/Datenschutz-
  /// Texte inhaltlich ändern — dann muss der Nutzer erneut zustimmen.
  static const currentTermsVersion = 1;

  /// Preis des PRO-Abos (nur Anzeige; die echte Abrechnung macht der Store).
  static const proPriceLabel = '9,99 €/Monat';

  /// Free-Tier: bis zu 20 gespeicherte Orte (aus dem Konzept).
  static const freeSaveLimit = 20;

  /// Owner-Freischaltung: In der App liegt NUR der SHA-256-Hash des geheimen
  /// Admin-Schlüssels, nie der Schlüssel selbst. Owner wird nur, wer den
  /// richtigen Schlüssel eingibt (siehe [unlockOwner]). Ein geratener
  /// Benutzername reicht also nicht mehr.
  ///
  /// ⚠️ Rein clientseitig lässt sich das nicht vollständig „hack-sicher" machen
  /// (wer die App dekompiliert, sieht die Prüf-Logik). Der echte, fälschungs-
  /// sichere Owner-Schutz kommt mit Supabase als serverseitige Rolle. Ein
  /// starker Schlüssel schützt aber zuverlässig gegen normale Nutzer.
  static const _adminKeyHash =
      '1ae91a8a48f0c41ba894c6272703beb989a5ce5e665de4980ad1b6c8b38ccfdd';

  /// Mindestlängen für die Anmeldung.
  static const minUsernameLength = 3;
  static const minPasswordLength = 6;

  final SpotRepository _repo;
  final SharedPreferences _prefs;
  final weather = WeatherService();
  BillingService? _billing;

  List<Spot> _spots = [];
  Set<String> _liked = {};
  Set<String> _saved = {};
  Set<String> _blockedSpots = {};
  Set<String> _blockedUsers = {};
  List<SpotReport> _reports = [];
  SpotFilters _filters = const SpotFilters();
  DateTime? _proUntil;
  bool _autoRenew = false;
  List<GiftCode> _giftCodes = [];
  bool _termsAccepted = false;
  DateTime? _termsAcceptedAt;
  String? _accUsername;
  String? _accPassHash;
  String? _accSalt;
  bool _signedIn = false;
  bool _accIsOwner = false;
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

    // Store-Käufe im Hintergrund initialisieren (blockiert den Start nicht).
    // Fällt auf Web/Desktop bzw. ohne konfiguriertes Produkt einfach weg.
    unawaited(state._initBilling());
    return state;
  }

  Future<void> _load() async {
    _spots = await _repo.all();
    _liked = await _repo.likedIds();
    _saved = await _repo.savedIds();
    _blockedSpots = await _repo.blockedSpotIds();
    _blockedUsers = await _repo.blockedUserNames();
    _reports = await _repo.openReports();
    _termsAccepted =
        (_prefs.getInt(_kTermsVersion) ?? 0) >= currentTermsVersion;
    final acceptedAt = _prefs.getString(_kTermsAcceptedAt);
    _termsAcceptedAt = acceptedAt == null ? null : DateTime.tryParse(acceptedAt);

    _accUsername = _prefs.getString(_kAccUsername);
    _accPassHash = _prefs.getString(_kAccPassHash);
    _accSalt = _prefs.getString(_kAccSalt);
    _signedIn = _prefs.getBool(_kSignedIn) ?? false;
    _accIsOwner = _prefs.getBool(_kAccIsOwner) ?? false;

    final until = _prefs.getString(_kProUntil);
    _proUntil = until == null ? null : DateTime.tryParse(until);
    _autoRenew = _prefs.getBool(_kAutoRenew) ?? false;

    _giftCodes = [];
    for (final c in _prefs.getStringList(_kGiftCodes) ?? const []) {
      try {
        _giftCodes.add(GiftCode.fromJson(jsonDecode(c) as Map<String, dynamic>));
      } catch (_) {}
    }

    _loading = false;
    notifyListeners();
  }

  // --- Lesen ---

  bool get loading => _loading;

  // --- Konto / Anmeldung ---

  /// Gibt es auf dem Gerät bereits ein Konto? (Dann Anmelden statt Registrieren.)
  bool get hasAccount => _accUsername != null && _accPassHash != null;

  /// Ist ein Nutzer gerade angemeldet?
  bool get isSignedIn => hasAccount && _signedIn;

  /// Nach der AGB-Zustimmung noch anmelden?
  bool get needsAuth => !isSignedIn;

  /// Bist du der Owner? Wird nur durch den korrekten Admin-Schlüssel
  /// freigeschaltet (siehe [unlockOwner]). Schaltet Moderation und
  /// Gift-Code-Erzeugung frei.
  bool get isOwner => isSignedIn && _accIsOwner;

  /// Zahlendes PRO läuft (Abo oder Gift-Code noch gültig).
  bool get hasPaidPro => _proUntil != null && _proUntil!.isAfter(DateTime.now());

  /// PRO ist aktiv, wenn ein Abo/Code läuft — oder der Owner es nutzt.
  bool get isPro => isOwner || hasPaidPro;

  /// Verlängert sich das Abo am Ende des Zeitraums automatisch?
  bool get autoRenew => _autoRenew;

  /// Muss der Nutzer den AGB erst noch zustimmen?
  bool get needsTermsConsent => !_termsAccepted;

  DateTime? get proUntil => _proUntil;

  /// Verbleibende PRO-Zeit als Text.
  String? get proRemainingLabel {
    if (!hasPaidPro) return null;
    final days = _proUntil!.difference(DateTime.now()).inDays;
    if (days >= 60) return 'noch ${(days / 30).round()} Monate';
    if (days >= 1) return 'noch $days Tage';
    return 'läuft heute ab';
  }

  /// Ablaufdatum als "TT.MM.JJJJ".
  String? get proUntilLabel {
    if (!hasPaidPro) return null;
    final d = _proUntil!;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  List<GiftCode> get giftCodes => List.unmodifiable(_giftCodes);
  List<SpotReport> get openReports => List.unmodifiable(_reports);
  Set<String> get blockedUsers => Set.of(_blockedUsers);
  Set<String> get blockedSpots => Set.of(_blockedSpots);

  List<Spot> get allSpots => _spots;
  SpotFilters get filters => _filters;
  Set<String> get savedIds => _saved;

  /// Ist ein Spot für normale Nutzer sichtbar? Gesperrte Spots und Spots
  /// gesperrter Nutzer verschwinden — nur der Owner sieht sie weiterhin.
  bool _isModerationVisible(Spot s) =>
      isOwner || (!_blockedSpots.contains(s.id) && !_blockedUsers.contains(s.authorName));

  /// Die Spots, die aktuell auf der Karte und in der Liste erscheinen.
  List<Spot> get visibleSpots =>
      _spots.where((s) => _isModerationVisible(s) && _filters.matches(s)).toList();

  /// Alle sichtbaren Spots ohne Filter (für Feed/Collections).
  List<Spot> get moderatedSpots => _spots.where(_isModerationVisible).toList();

  List<Spot> get savedSpots => _spots.where((s) => _saved.contains(s.id)).toList();

  /// Anzeigename des aktuellen Nutzers — der Benutzername, sonst der Fallback
  /// des Repositories.
  String get currentUserName => _accUsername ?? _repo.currentUserName;

  List<Spot> get mySpots =>
      _spots.where((s) => s.authorName == currentUserName).toList();

  bool get isSpotBlocked => false; // (nur für Klarheit; Einzelabfrage unten)
  bool spotBlocked(String id) => _blockedSpots.contains(id);
  bool userBlocked(String name) => _blockedUsers.contains(name);

  /// Darf der aktuelle Nutzer diesen Spot löschen? Nur der Autor selbst.
  /// (Der Owner entfernt fremde Spots über die Moderation per „Sperren", nicht
  /// per Löschen — Löschen bleibt allein dem Ersteller vorbehalten.)
  bool canDelete(Spot s) => s.authorName == currentUserName;

  /// Hidden Gems sind ein PRO-Feature — im Free-Tier bleiben sie verborgen.
  List<Spot> get hiddenGems =>
      isPro ? moderatedSpots.where((s) => s.isHiddenGem).toList() : const [];

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

  /// Löscht einen Spot (Autor oder Owner).
  Future<void> deleteSpot(String id) async {
    await _repo.delete(id);
    _spots = await _repo.all();
    _saved = await _repo.savedIds();
    _liked = await _repo.likedIds();
    _reports = await _repo.openReports();
    notifyListeners();
  }

  /// Wann der Nutzer zuletzt zugestimmt hat (Nachweis).
  DateTime? get termsAcceptedAt => _termsAcceptedAt;

  /// Zustimmung als "TT.MM.JJJJ, HH:MM" für die Anzeige.
  String? get termsAcceptedLabel {
    final d = _termsAcceptedAt;
    if (d == null) return null;
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}.${p(d.month)}.${d.year}, ${p(d.hour)}:${p(d.minute)}';
  }

  /// Bestätigt die Zustimmung zu AGB & Datenschutz (beim ersten Start).
  /// Protokolliert Version und Zeitpunkt als Nachweis der Einwilligung.
  Future<void> acceptTerms() async {
    _termsAccepted = true;
    _termsAcceptedAt = DateTime.now();
    await _prefs.setInt(_kTermsVersion, currentTermsVersion);
    await _prefs.setString(_kTermsAcceptedAt, _termsAcceptedAt!.toIso8601String());
    notifyListeners();
  }

  /// Registriert ein neues Konto mit Benutzername + Passwort (lokal gespeichert,
  /// Passwort als gesalzener SHA-256-Hash — nie im Klartext).
  ///
  /// Mit Supabase wird daraus eine echte Registrierung über Supabase Auth.
  Future<AuthOutcome> register(String username, String password) async {
    final u = username.trim();
    if (u.length < minUsernameLength) return AuthOutcome.usernameTooShort;
    if (password.length < minPasswordLength) return AuthOutcome.passwordTooShort;

    final salt = _newSalt();
    _accSalt = salt;
    _accPassHash = _hash(password, salt);
    _accUsername = u;
    _signedIn = true;
    _accIsOwner = false; // Owner wird nur über den Admin-Schlüssel freigeschaltet.

    await _prefs.setString(_kAccUsername, u);
    await _prefs.setString(_kAccPassHash, _accPassHash!);
    await _prefs.setString(_kAccSalt, salt);
    await _prefs.setBool(_kSignedIn, true);
    await _prefs.setBool(_kAccIsOwner, false);
    notifyListeners();
    return AuthOutcome.success;
  }

  /// Schaltet Owner-Rechte frei, wenn der eingegebene Admin-Schlüssel stimmt.
  /// Verglichen wird nur der SHA-256-Hash — der Schlüssel steht nirgends in der App.
  Future<bool> unlockOwner(String key) async {
    final hash = sha256.convert(utf8.encode(key.trim())).toString();
    if (hash != _adminKeyHash) return false;
    _accIsOwner = true;
    await _prefs.setBool(_kAccIsOwner, true);
    notifyListeners();
    return true;
  }

  /// Gibt die Owner-Rechte wieder ab (ohne das Konto zu löschen).
  Future<void> revokeOwner() async {
    _accIsOwner = false;
    await _prefs.setBool(_kAccIsOwner, false);
    notifyListeners();
  }

  /// Meldet ein bestehendes Konto an (Benutzername + Passwort prüfen).
  Future<AuthOutcome> login(String username, String password) async {
    if (!hasAccount) return AuthOutcome.noAccount;
    if (username.trim().toLowerCase() != _accUsername!.toLowerCase()) {
      return AuthOutcome.wrongCredentials;
    }
    if (_hash(password, _accSalt!) != _accPassHash) {
      return AuthOutcome.wrongCredentials;
    }
    _signedIn = true;
    await _prefs.setBool(_kSignedIn, true);
    notifyListeners();
    return AuthOutcome.success;
  }

  /// Meldet ab — das Konto bleibt bestehen, nur die Sitzung endet.
  /// Die Daten (Spots) bleiben erhalten.
  Future<void> signOut() async {
    _signedIn = false;
    await _prefs.setBool(_kSignedIn, false);
    notifyListeners();
  }

  /// Löscht das Konto samt der selbst erstellten Spots (Apple-Store-Anforderung).
  Future<void> deleteAccount() async {
    for (final s in mySpots.toList()) {
      await _repo.delete(s.id);
    }
    _spots = await _repo.all();

    _accUsername = null;
    _accPassHash = null;
    _accSalt = null;
    _signedIn = false;
    _accIsOwner = false;
    await _prefs.remove(_kAccUsername);
    await _prefs.remove(_kAccPassHash);
    await _prefs.remove(_kAccSalt);
    await _prefs.remove(_kSignedIn);
    await _prefs.remove(_kAccIsOwner);
    notifyListeners();
  }

  static String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List.generate(16, (_) => r.nextInt(256)));
  }

  static String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  // --- PRO-Abo ---

  /// Schließt das PRO-Abo ab (Demo: ohne echte Zahlung). Verlängert die Laufzeit
  /// um einen Monat und aktiviert die automatische Verlängerung.
  Future<void> purchasePro() async {
    final base = hasPaidPro ? _proUntil! : DateTime.now();
    _proUntil = DateTime(base.year, base.month + 1, base.day, base.hour, base.minute);
    _autoRenew = true;
    await _prefs.setString(_kProUntil, _proUntil!.toIso8601String());
    await _prefs.setBool(_kAutoRenew, true);
    notifyListeners();
  }

  // --- Store-Käufe (Google Play / App Store) ---

  Future<void> _initBilling() async {
    _billing = BillingService(onPurchased: () => purchasePro());
    await _billing!.init();
    await _billing!.restore(); // bestehende Abonnenten wieder freischalten
    notifyListeners();
  }

  /// Sind echte Store-Käufe verfügbar (Produkt konfiguriert)?
  bool get billingAvailable => _billing?.available ?? false;

  /// Preis direkt vom Store (z. B. "9,99 €"), sonst der Standard-Text.
  String get proPriceDisplay => _billing?.priceLabel ?? proPriceLabel;

  /// Startet den echten Store-Kauf. Gibt false zurück, wenn nicht verfügbar —
  /// dann nutzt die Paywall den Demo-/Gutschein-Weg.
  Future<bool> buyProViaStore() async => await _billing?.buyPro() ?? false;

  /// Stellt frühere Käufe wieder her („Käufe wiederherstellen").
  Future<void> restorePurchases() async => await _billing?.restore();

  /// Kündigt das Abo: keine automatische Verlängerung mehr, aber PRO bleibt bis
  /// zum Ende des bereits bezahlten Zeitraums aktiv.
  Future<void> cancelSubscription() async {
    _autoRenew = false;
    await _prefs.setBool(_kAutoRenew, false);
    notifyListeners();
  }

  /// Reaktiviert die automatische Verlängerung (Kündigung zurücknehmen).
  Future<void> resumeSubscription() async {
    _autoRenew = true;
    await _prefs.setBool(_kAutoRenew, true);
    notifyListeners();
  }

  // --- Moderation ---

  Future<void> reportSpot(String id, String reason) async {
    await _repo.report(id, reason, currentUserName);
    _reports = await _repo.openReports();
    notifyListeners();
  }

  Future<void> setSpotBlocked(String id, bool blocked) async {
    await _repo.setSpotBlocked(id, blocked);
    _blockedSpots = await _repo.blockedSpotIds();
    _reports = await _repo.openReports();
    notifyListeners();
  }

  Future<void> setUserBlocked(String userName, bool blocked) async {
    await _repo.setUserBlocked(userName, blocked);
    _blockedUsers = await _repo.blockedUserNames();
    notifyListeners();
  }

  Future<void> dismissReport(String reportId) async {
    await _repo.dismissReport(reportId);
    _reports = await _repo.openReports();
    notifyListeners();
  }

  /// Spot zu einer Meldung nachschlagen (für die Owner-Übersicht).
  Spot? reportedSpot(SpotReport r) => spotById(r.spotId);

  // --- PRO / Gift-Codes ---

  /// Owner erzeugt einen Code, der PRO für [months] Monate freischaltet.
  Future<GiftCode> generateGiftCode(int months) async {
    final code = _randomCode();
    final gc = GiftCode(code: code, months: months, createdAt: DateTime.now());
    _giftCodes = [gc, ..._giftCodes];
    await _persistGiftCodes();
    notifyListeners();
    return gc;
  }

  Future<void> deleteGiftCode(String code) async {
    _giftCodes = _giftCodes.where((c) => c.code != code).toList();
    await _persistGiftCodes();
    notifyListeners();
  }

  /// Löst einen Code ein und verlängert PRO um die enthaltenen Monate.
  RedeemResult redeemCode(String rawCode) {
    final code = rawCode.trim().toUpperCase().replaceAll(' ', '');
    if (code.isEmpty) return RedeemResult.invalid;

    final index = _giftCodes.indexWhere((c) => c.code == code);
    if (index == -1) return RedeemResult.invalid;
    if (_giftCodes[index].redeemed) return RedeemResult.alreadyUsed;

    final gc = _giftCodes[index];
    _giftCodes[index] = gc.markRedeemed();

    // Ab jetzt (oder ab bestehendem Ablauf) um die Monate verlängern.
    final base = (_proUntil != null && _proUntil!.isAfter(DateTime.now()))
        ? _proUntil!
        : DateTime.now();
    _proUntil = DateTime(base.year, base.month + gc.months, base.day,
        base.hour, base.minute);

    _persistGiftCodes();
    _prefs.setString(_kProUntil, _proUntil!.toIso8601String());
    notifyListeners();
    return RedeemResult.success;
  }

  Future<void> _persistGiftCodes() async {
    await _prefs.setStringList(
      _kGiftCodes,
      _giftCodes.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  static String _randomCode() {
    // Verwechslungsfreie Zeichen (kein 0/O, 1/I). Format: TERRA-XXXX-XXXX.
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    String block() =>
        List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
    return 'TERRA-${block()}-${block()}';
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

enum RedeemResult { success, invalid, alreadyUsed }

enum AuthOutcome {
  success,
  usernameTooShort,
  passwordTooShort,
  wrongCredentials,
  noAccount;

  String? get message => switch (this) {
        AuthOutcome.success => null,
        AuthOutcome.usernameTooShort =>
          'Der Benutzername ist zu kurz (mind. ${AppState.minUsernameLength} Zeichen).',
        AuthOutcome.passwordTooShort =>
          'Das Passwort ist zu kurz (mind. ${AppState.minPasswordLength} Zeichen).',
        AuthOutcome.wrongCredentials => 'Benutzername oder Passwort ist falsch.',
        AuthOutcome.noAccount => 'Es existiert noch kein Konto. Bitte registrieren.',
      };
}

/// Ein vom Owner erzeugter Code, der PRO für eine Anzahl Monate freischaltet.
class GiftCode {
  const GiftCode({
    required this.code,
    required this.months,
    required this.createdAt,
    this.redeemed = false,
    this.redeemedAt,
  });

  final String code;
  final int months;
  final DateTime createdAt;
  final bool redeemed;
  final DateTime? redeemedAt;

  GiftCode markRedeemed() => GiftCode(
        code: code,
        months: months,
        createdAt: createdAt,
        redeemed: true,
        redeemedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'months': months,
        'createdAt': createdAt.toIso8601String(),
        'redeemed': redeemed,
        'redeemedAt': redeemedAt?.toIso8601String(),
      };

  factory GiftCode.fromJson(Map<String, dynamic> j) => GiftCode(
        code: j['code'] as String,
        months: j['months'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        redeemed: (j['redeemed'] as bool?) ?? false,
        redeemedAt: j['redeemedAt'] == null
            ? null
            : DateTime.parse(j['redeemedAt'] as String),
      );
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
