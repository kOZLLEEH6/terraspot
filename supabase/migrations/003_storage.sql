-- Storage-Bucket für Spot-Fotos.
-- Fotos sind öffentlich lesbar (Galerie), Upload nur für Angemeldete.

insert into storage.buckets (id, name, public)
values ('spot-photos', 'spot-photos', true)
on conflict (id) do nothing;

create policy "Spot-Fotos sind öffentlich lesbar"
  on storage.objects for select
  using (bucket_id = 'spot-photos');

create policy "Angemeldete dürfen Fotos hochladen"
  on storage.objects for insert
  with check (bucket_id = 'spot-photos' and auth.role() = 'authenticated');

create policy "Nutzer dürfen eigene Fotos löschen"
  on storage.objects for delete
  using (bucket_id = 'spot-photos' and owner = auth.uid());
