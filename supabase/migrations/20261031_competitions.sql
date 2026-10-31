-- Weekly paper-based competition tracking
-- One competition per week, shared across all classes.
-- Servants enter numeric marks per child; marks accumulate over the year.

create table public.competitions (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  week_date   date not null unique,
  max_mark    smallint not null default 10
                check (max_mark between 1 and 100),
  year_id     uuid references public.attendance_years(id) on delete set null,
  created_by  uuid not null references public.profiles(id),
  created_at  timestamptz not null default now()
);

create table public.competition_marks (
  id              uuid primary key default gen_random_uuid(),
  competition_id  uuid not null references public.competitions(id) on delete cascade,
  child_id        uuid not null references public.children(id) on delete cascade,
  mark            smallint not null check (mark >= 0),
  marked_by       uuid not null references public.profiles(id),
  marked_at       timestamptz not null default now(),
  unique (competition_id, child_id)
);

-- Cumulative totals per child across all competitions
create view public.v_child_competition_scores as
select
  cm.child_id,
  c.full_name                       as child_name,
  c.class_id,
  count(*)::int                     as competitions_count,
  sum(cm.mark)::int                 as total_marks,
  round(avg(cm.mark)::numeric, 1)   as avg_mark
from public.competition_marks cm
join public.children c on c.id = cm.child_id
group by cm.child_id, c.full_name, c.class_id;

-- RLS
alter table public.competitions     enable row level security;
alter table public.competition_marks enable row level security;

-- competitions: all authenticated users can read; only admin can write
create policy "competitions_select" on public.competitions
  for select using (auth.role() = 'authenticated');

create policy "competitions_insert" on public.competitions
  for insert with check (public.is_admin());

create policy "competitions_update" on public.competitions
  for update using (public.is_admin());

create policy "competitions_delete" on public.competitions
  for delete using (public.is_admin());

-- competition_marks: servant can read/write marks for children in their classes
create policy "competition_marks_select" on public.competition_marks
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.class_servants cs
      join public.children ch on ch.class_id = cs.class_id
      where cs.servant_id = auth.uid()
        and ch.id = competition_marks.child_id
    )
  );

create policy "competition_marks_upsert" on public.competition_marks
  for insert with check (
    public.is_admin()
    or exists (
      select 1 from public.class_servants cs
      join public.children ch on ch.class_id = cs.class_id
      where cs.servant_id = auth.uid()
        and ch.id = competition_marks.child_id
    )
  );

create policy "competition_marks_update" on public.competition_marks
  for update using (
    public.is_admin()
    or marked_by = auth.uid()
  );

create policy "competition_marks_delete" on public.competition_marks
  for delete using (
    public.is_admin()
    or marked_by = auth.uid()
  );
