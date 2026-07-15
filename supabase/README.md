# Supabase-Anbindung für TerraSpot

Die App läuft standardmäßig gegen ein **Mock-Repository** (30 Beispiel-Spots, lokal).
Sobald Supabase-Zugangsdaten übergeben werden, schaltet sie automatisch auf das
`SupabaseSpotRepository` um — dieselbe Schnittstelle, dieselbe UI.

## 1. Projekt anlegen

1. Auf [supabase.com](https://supabase.com) ein kostenloses Projekt erstellen.
2. Unter **Project Settings → API** notieren:
   - `Project URL` (z. B. `https://xxxx.supabase.co`)
   - `anon public` Key

## 2. Schema einspielen

Im Supabase-Dashboard unter **SQL Editor** die Dateien der Reihe nach ausführen:

```
supabase/migrations/001_schema.sql   -- Tabellen, Views, Indizes
supabase/migrations/002_rls.sql      -- Row Level Security + Auto-Profil
supabase/migrations/003_storage.sql  -- Foto-Bucket
```

## 3. App mit Zugangsdaten starten

Die Schlüssel werden **nicht** ins Repo geschrieben, sondern beim Start übergeben:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=dein-anon-key
```

Für Release-Builds analog:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Ohne diese Werte startet die App unverändert im Mock-Modus — praktisch für
Entwicklung und Demo.

## 4. (Optional) Beispiel-Spots migrieren

Die 30 Mock-Spots lassen sich als Startbestand in die echte DB laden. Ein
Seed-Skript dafür kann aus `lib/core/data/mock_data.dart` generiert werden —
sag Bescheid, dann lege ich es an.
