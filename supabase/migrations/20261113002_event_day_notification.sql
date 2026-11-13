-- On the day of an event (نشاط ترفيهي), at 6:00 Cairo time, every active
-- servant and admin gets a reminder: "نشاط اليوم" with the event's title.
--
-- Kind 'event_today' has no screen in the app, so tapping it only marks it
-- read (no routing), and it shows with the bell's default icon.
--
-- pg_cron runs in UTC and Cairo moves between UTC+2 and UTC+3, so the job
-- runs at both 03:00 and 04:00 UTC and only acts in the hour that is 6 AM in
-- Cairo. One reminder per event per person, even if the job runs twice.

create or replace function public.notify_events_today(p_force boolean default false)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_now   timestamp := now() at time zone 'Africa/Cairo';
  v_today date := v_now::date;
  v_sent  integer;
begin
  if not p_force and extract(hour from v_now) <> 6 then
    return 0;
  end if;

  insert into public.notifications (user_id, kind, title, body, ref_id)
  select p.id,
         'event_today',
         'نشاط اليوم 🎉',
         e.title || coalesce(' — ' || nullif(left(btrim(e.description), 120), ''), ''),
         e.id
  from public.events e
  cross join public.profiles p
  where e.event_date = v_today
    and p.is_active
    and not p.is_hidden
    and p.role in ('admin', 'servant', 'general_servant')
    and not exists (
      select 1 from public.notifications n
      where n.user_id = p.id and n.kind = 'event_today' and n.ref_id = e.id
    );
  get diagnostics v_sent = row_count;
  return v_sent;
end;
$$;

revoke all on function public.notify_events_today(boolean) from public, anon, authenticated;

select cron.unschedule('daily-event-today')
where exists (select 1 from cron.job where jobname = 'daily-event-today');

select cron.schedule('daily-event-today', '0 3,4 * * *',
                     'select public.notify_events_today()');
