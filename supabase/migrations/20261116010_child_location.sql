-- A child's home on the map: a servant can save it (from a Google Maps link,
-- coordinates, or the phone's current location when visiting) and open it later
-- for directions.
--
-- Both or neither: a latitude without a longitude means nothing. The ordinary
-- children row rules apply, so only the servants of the child's class (and the
-- admins) can read or change it. It is personal data: it is in the weekly
-- backup, which is encrypted.

alter table public.children
  add column if not exists latitude  double precision,
  add column if not exists longitude double precision;

alter table public.children
  drop constraint if exists children_location_valid;

alter table public.children
  add constraint children_location_valid check (
    (latitude is null and longitude is null)
    or (latitude between -90 and 90 and longitude between -180 and 180
        and latitude is not null and longitude is not null)
  );

comment on column public.children.latitude is
  'Home location (degrees north). Set together with longitude, or both null.';
comment on column public.children.longitude is
  'Home location (degrees east). Set together with latitude, or both null.';
