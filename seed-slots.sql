-- Fill public.slots from granular schedule rows.
-- Edit the schedule values before running this in the Supabase SQL editor.
--
-- Each schedule row creates one row per required person and time chunk.
-- This supports different days, locations, opening hours, chunk sizes, and
-- person counts. Add multiple rows for the same day/location if the chunk size
-- changes during the day.

create unique index if not exists slots_unique_seed_idx
on public.slots(day, location, start, "end", name);

with schedule as (
  select *
  from (values
    -- day, location, first_start, last_end, chunk_size, persons_required
    ('2026-05-22'::date, 'Wannebar',      time '08:00', time '12:00', interval '1 hour',  2),
    ('2026-05-22'::date, 'Wannebar',      time '12:00', time '20:00', interval '2 hours', 2),
    ('2026-05-22'::date, 'Grill',         time '10:00', time '18:00', interval '2 hours', 2),
    ('2026-05-22'::date, 'Kuchenverkauf', time '09:00', time '15:00', interval '1 hour',  1),
    ('2026-05-22'::date, 'Getraenke',     time '08:00', time '20:00', interval '2 hours', 1),

    ('2026-05-23'::date, 'Wannebar',      time '08:00', time '19:00', interval '1 hour',  2),
    ('2026-05-23'::date, 'Grill',         time '10:00', time '18:00', interval '2 hours', 2),
    ('2026-05-23'::date, 'Kuchenverkauf', time '09:00', time '16:00', interval '1 hour',  1),
    ('2026-05-23'::date, 'Getraenke',     time '08:00', time '19:00', interval '1 hour',  1)
  ) as value(slot_day, location, first_start, last_end, chunk_size, persons_required)
),
chunks as (
  select
    slot_day,
    location,
    person_no,
    start_at,
    least(start_at + chunk_size, slot_day + last_end) as end_at
  from schedule
  cross join generate_series(1, persons_required) as person_no
  cross join lateral generate_series(
    slot_day + first_start,
    slot_day + last_end - interval '1 minute',
    chunk_size
  ) as series(start_at)
)
insert into public.slots (name, is_taken, day, location, start, "end")
select
  to_char(slot_day, 'YYYY-MM-DD') || ' ' ||
    to_char(start_at, 'HH24:MI') || '-' ||
    to_char(end_at, 'HH24:MI') ||
    ' ' || location ||
    ' Slot ' || person_no as name,
  false as is_taken,
  slot_day,
  location,
  start_at at time zone 'Europe/Berlin',
  end_at at time zone 'Europe/Berlin'
from chunks
where start_at < end_at
order by slot_day, start_at, location, person_no
on conflict (day, location, start, "end", name) do nothing;
