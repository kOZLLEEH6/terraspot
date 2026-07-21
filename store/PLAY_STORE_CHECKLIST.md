# TerraSpot — Weg in den Google Play Store

Stand nach dieser Runde. ✅ = erledigt · ⬜ = du musst es tun.

## Technisch (App)
- ✅ Signiertes App Bundle: `TerraSpot-v1.0.0.aab` (Desktop) mit eigenem Upload-Key
- ✅ Upload-Keystore: `android/terraspot-upload.p12` (NICHT im Git)
      SHA1: `1B:33:ED:65:C7:38:2C:BE:87:20:33:14:C9:36:7E:93:72:D1:3B:7A`
- ✅ Foto-Lizenzen: alle 90 Fotos frei lizenziert (CC BY / CC BY-SA / CC0 / gemeinfrei),
      Bildnachweise in der App unter Profil → Rechtliches → Bildnachweise
- ✅ In-App-Kauf-Gerüst (Google Play Billing) — Produkt-ID `terraspot_pro_monthly`
- ✅ Konto-Löschung in der App (Profil → Konto löschen)
- ✅ Owner nur per geheimem Schlüssel (nicht per Benutzername)

## ⬜ WICHTIG: Keystore sichern
Der Upload-Key liegt NUR lokal unter `android/terraspot-upload.p12`.
**Passwort:** `cDjaQ9rIYAZ3VgZhdByZ` (Alias: `upload`).
Geht der Key verloren, kannst du **nie wieder Updates hochladen**. Sichere die
Datei + das Passwort an einem sicheren Ort (Passwortmanager, Backup).
Tipp: In der Play Console „Play App Signing" aktivieren (Standard) — dann ist
dieser Key nur der Upload-Key und Google verwaltet den finalen Signaturschlüssel.

## ⬜ Play Console (du, einmalig)
1. Entwicklerkonto anlegen (25 $ einmalig), Identität verifizieren.
2. Neue App „TerraSpot" anlegen.
3. `TerraSpot-v1.0.0.aab` in einen Testtrack (intern) hochladen.
4. Store-Eintrag ausfüllen — Texte in `store/STORE_LISTING.md`.
5. Screenshots hochladen (kann ich aus der App erzeugen — sag Bescheid).
6. Data-Safety-Formular: Standort (nur mit Erlaubnis, kein Hintergrund),
   Nutzerfotos, Konto. Kein Datenverkauf.
7. Inhaltseinstufung + Zielgruppe ausfüllen.

## ⬜ Rechtsdokumente hosten (du)
Die HTML-Dateien in `store/web/` online stellen (eigene Domain oder z. B. GitHub
Pages) und die URLs in der Play Console eintragen:
- `datenschutz.html`  → Datenschutz-URL (Pflicht)
- `impressum.html`
- `konto-loeschen.html` → URL für Kontolöschung (Pflicht)
Vorher alle `[Platzhalter]` ausfüllen und **anwaltlich prüfen lassen**.

## ⬜ In-App-Kauf aktivieren (du)
1. In der Play Console unter „Monetarisierung → Abos" ein Abo mit der ID
   **`terraspot_pro_monthly`** anlegen (9,99 €/Monat).
2. Auf einem echten Gerät über den internen Testtrack testen — dann schaltet
   die App automatisch vom Demo- auf den echten Kauf um.
3. Ohne dieses Produkt bleibt der Demo-Kauf aktiv (App funktioniert trotzdem).

## Noch offen / empfohlen
- ⬜ **iOS**: eigener Weg (Apple Developer 99 $/Jahr, App Store Connect, Signierung
      auf Mac/Cloud). Der GitHub-iOS-Build ist vorbereitet.
- ⬜ **Supabase-Backend**: aktuell liegen Konten & Spots nur lokal auf dem Gerät.
      Für echten Betrieb (geräteübergreifend, „Passwort vergessen") empfohlen.
- ⬜ Eigene App-Store-Firmendaten (Impressum) eintragen.

## Zum direkten Testen
`TerraSpot-v1.0.0.apk` (Desktop) auf ein Android-Handy laden. Das `.aab` ist nur
für den Play-Upload, nicht direkt installierbar.
