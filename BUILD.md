# TerraSpot — Build & Installation

## Android (fertig gebaut)

Die Release-APK liegt nach dem Build unter:

```
build/app/outputs/flutter-apk/app-release.apk
```

**Auf ein Android-Handy bringen:**

1. APK per USB, E-Mail, Cloud o. Ä. aufs Handy kopieren.
2. Beim Öffnen fragt Android nach der Erlaubnis „Apps aus dieser Quelle installieren" — erlauben.
3. Installieren, öffnen. Beim ersten Standortzugriff fragt die App nach der GPS-Berechtigung.

> Es ist eine unsignierte Debug-Signatur (Standard-Release-Key von Flutter). Für den
> Play Store später einen eigenen Upload-Key erzeugen und in `android/key.properties`
> hinterlegen — dann `flutter build appbundle` für das `.aab`.

**Selbst neu bauen (Windows):**

```bash
export PATH="/c/dev/flutter/bin:$PATH"
export JAVA_HOME="/c/dev/jdk-17.0.19+10"
export ANDROID_SDK_ROOT="/c/dev/android-sdk"
cd PicMap/terraspot
flutter build apk --release
```

---

## iOS (auf Windows nicht baubar — braucht einen Mac)

iOS-Apps lassen sich ausschließlich auf macOS mit Xcode kompilieren. Das Projekt
ist dafür bereits vorbereitet: Bundle-ID `com.terraspot.terraspot`, Anzeigename
„TerraSpot", Standort-Berechtigung in `ios/Runner/Info.plist`.

**Auf einem Mac:**

```bash
cd PicMap/terraspot
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace     # in Xcode Signing-Team wählen
flutter build ipa               # oder: flutter run  (auf angeschlossenem iPhone)
```

Für die Installation auf einem echten iPhone brauchst du ein Apple-Developer-Konto
(kostenlos für 7-Tage-Testinstallation, 99 $/Jahr für TestFlight/App Store).

---

## Cloud-Build für beide Plattformen (kein eigener Mac nötig)

`codemagic.yaml` liegt im Projektwurzelverzeichnis. Damit baut Codemagic
(kostenloses Kontingent) Android **und** iOS in der Cloud:

1. Repo zu GitHub/GitLab pushen.
2. Auf codemagic.io mit dem Repo verbinden.
3. Für iOS-Signierung: Apple-Developer-Konto in Codemagic hinterlegen.

---

## Was in dieser Version steckt

- 30 kuratierte Spots mit echten Fotos, Weltkarte mit Clustering
- GPS-Automatik: Standort beim Erstellen, Umkreisfilter, „in deiner Nähe"
- PRO: Wetter-Score (Open-Meteo, live), Golden Hour & Astronomie, Crowd-Prognose,
  Heatmap, Routenplaner, Collections, Fotografie-Modus, Hidden Gems
- Daten aktuell aus Mock-Repository; Supabase wird hinter demselben Interface angebunden
