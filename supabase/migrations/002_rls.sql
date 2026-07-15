-- Row Level Security: Spots sind öffentlich lesbar, aber nur der Autor darf
-- seine eigenen ändern. Likes/Saves gehören dem jeweiligen Nutzer.

alter table profiles enable row level security;
alter table spots    enable row level security;
alter table likes    enable row level security;
alter table saves    enable row level security;

-- Profile: jeder sieht Profile, aber jeder bearbeitet nur sein eigenes.
create policy "Profile sind lesbar"
  on profiles for select using (true);
create policy "Eigenes Profil anlegen"
  on profiles for insert with check (auth.uid() = id);
create policy "Eigenes Profil ändern"
  on profiles for update using (auth.uid() = id);

-- Spots: öffentlich lesbar (die Karte ist für alle da).
create policy "Spots sind öffentlich lesbar"
  on spots for select using (true);
create policy "Angemeldete dürfen Spots erstellen"
  on spots for insert with check (auth.uid() = author_id);
create policy "Nur der Autor darf seinen Spot ändern"
  on spots for update using (auth.uid() = author_id);
create policy "Nur der Autor darf seinen Spot löschen"
  on spots for delete using (auth.uid() = author_id);

-- Likes: jeder sieht die Likes (für Zähler), aber setzt nur eigene.
create policy "Likes sind lesbar"
  on likes for select using (true);
create policy "Eigene Likes setzen"
  on likes for insert with check (auth.uid() = user_id);
create policy "Eigene Likes entfernen"
  on likes for delete using (auth.uid() = user_id);

-- Saves: privat — nur der Nutzer selbst sieht und verwaltet seine.
create policy "Eigene Saves lesen"
  on saves for select using (auth.uid() = user_id);
create policy "Eigene Saves setzen"
  on saves for insert with check (auth.uid() = user_id);
create policy "Eigene Saves entfernen"
  on saves for delete using (auth.uid() = user_id);

-- Beim Registrieren automatisch ein Profil anlegen.
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', 'Entdecker'));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
