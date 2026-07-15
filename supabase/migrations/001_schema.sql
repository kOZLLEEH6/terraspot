-- TerraSpot — Datenbankschema
-- Spiegelt das Spot-Modell aus lib/core/models/spot.dart 1:1 wider,
-- damit SupabaseSpotRepository ohne Feld-Übersetzung auskommt.

-- Profile hängen an Supabase Auth (auth.users).
create table if not exists profiles (
  id          uuid primary key references auth.users on delete cascade,
  display_name text not null,
  is_pro      boolean not null default false,
  created_at  timestamptz not null default now()
);

create table if not exists spots (
  id            uuid primary key default gen_random_uuid(),
  author_id     uuid not null references profiles(id) on delete cascade,
  author_name   text not null,
  title         text not null check (char_length(title) between 3 and 120),
  description   text not null,
  category      text not null,          -- entspricht SpotCategory.name
  lat           double precision not null check (lat between -90 and 90),
  lng           double precision not null check (lng between -180 and 180),
  country       text not null,
  region        text not null,
  photo_urls    text[] not null default '{}',
  rating        double precision not null default 0,
  rating_count  int not null default 0,
  best_time_of_day text not null,       -- "HH:mm"
  best_months   int[] not null default '{}',
  difficulty    text not null,          -- Difficulty.name
  hike_minutes  int not null default 0,
  hike_km       double precision not null default 0,
  elevation_m   int not null default 0,
  has_parking   boolean not null default false,
  dogs_allowed  boolean not null default false,
  kids_friendly boolean not null default false,
  camping_allowed boolean not null default false,
  visitors_per_day int not null default 0,
  created_at    timestamptz not null default now()
);

create index if not exists spots_category_idx on spots (category);
create index if not exists spots_author_idx   on spots (author_id);
-- Für Umkreissuchen: grobe Vorfilterung über lat/lng
create index if not exists spots_geo_idx       on spots (lat, lng);

-- Likes: ein Datensatz pro (Nutzer, Spot)
create table if not exists likes (
  user_id  uuid not null references profiles(id) on delete cascade,
  spot_id  uuid not null references spots(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, spot_id)
);

-- Gespeicherte Orte
create table if not exists saves (
  user_id  uuid not null references profiles(id) on delete cascade,
  spot_id  uuid not null references spots(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, spot_id)
);

-- Like-Zähler als View, damit er immer konsistent ist (kein manuelles Hochzählen).
create or replace view spot_like_counts as
  select spot_id, count(*)::int as likes
  from likes group by spot_id;
