import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Kapselt den Zugriff auf den Gerätestandort.
///
/// Funktioniert auf allen drei Plattformen: im Web über die Browser-Geolocation-
/// API, auf Android/iOS nativ. Der Rest der App kennt nur [LocationResult] und
/// muss sich nicht um Berechtigungen oder Plattformunterschiede kümmern.
class LocationService {
  /// Holt den aktuellen Standort und übersetzt jeden Fehlerfall in ein
  /// verständliches Ergebnis — es fliegt bewusst keine Exception nach oben,
  /// damit die UI immer eine klare Meldung zeigen kann statt eines Absturzes.
  static Future<LocationResult> current() async {
    try {
      // Berechtigung zuerst — auf Web löst das den Browser-Dialog aus.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return LocationResult.error(
          LocationError.denied,
          'Standortzugriff wurde abgelehnt.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationResult.error(
          LocationError.deniedForever,
          'Standortzugriff ist dauerhaft gesperrt — bitte in den Einstellungen erlauben.',
        );
      }

      // Der Dienst-Check ist nur nativ verlässlich; im Web meldet er je nach
      // Browser fälschlich "aus" und würde die Ortung grundlos blockieren.
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        return LocationResult.error(
          LocationError.serviceOff,
          'Ortungsdienste sind ausgeschaltet.',
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return LocationResult.success(
        LatLng(pos.latitude, pos.longitude),
        accuracyMeters: pos.accuracy,
      );
    } catch (e) {
      return LocationResult.error(
        LocationError.unavailable,
        'Standort konnte nicht ermittelt werden ($e).',
      );
    }
  }

  /// Ist eine Berechtigung schon erteilt? (Ohne einen Dialog auszulösen.)
  static Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }
}

enum LocationError { serviceOff, denied, deniedForever, unavailable }

class LocationResult {
  const LocationResult._({this.position, this.accuracyMeters, this.error, this.message});

  factory LocationResult.success(LatLng position, {double? accuracyMeters}) =>
      LocationResult._(position: position, accuracyMeters: accuracyMeters);

  factory LocationResult.error(LocationError error, String message) =>
      LocationResult._(error: error, message: message);

  final LatLng? position;
  final double? accuracyMeters;
  final LocationError? error;
  final String? message;

  bool get isSuccess => position != null;
}
