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
    -- day, day_name, location, first_start, last_end, chunk_size, persons_required
    -- Important: the last row before the closing parenthesis must not have a trailing comma.
    ('2026-05-21'::date, 'Freitag',   'Aufbau',             time '15:00', time '18:00', interval '3 hour',  15),

    ('2026-05-22'::date, 'Samstag', 'Wannebar',           time '08:30', time '18:30', interval '2 hour',  2),
    ('2026-05-22'::date, 'Samstag', 'Kuchenstand',        time '08:30', time '18:30', interval '2 hours', 3),
    ('2026-05-22'::date, 'Samstag', 'Getraenke',          time '08:30', time '18:30', interval '2 hours', 3),
    ('2026-05-22'::date, 'Samstag', 'Slushi + Sandwich',  time '08:30', time '18:30', interval '2 hour',  3),
    ('2026-05-22'::date, 'Samstag', 'Human Kicker',       time '16:00', time '18:00', interval '2 hours', 2),
    ('2026-05-22'::date, 'Samstag', 'Tische abwischen',   time '07:00', time '09:00', interval '2 hours', 2),
    ('2026-05-22'::date, 'Samstag', 'Tische abwischen',   time '12:30', time '14:30', interval '2 hours', 2),
    ('2026-05-22'::date, 'Samstag', 'Tische abwischen',   time '19:00', time '21:00', interval '2 hours', 2),

    ('2026-05-23'::date, 'Sonntag',   'Wannebar',           time '08:30', time '18:30', interval '2 hour',  2),
    ('2026-05-23'::date, 'Sonntag',   'Kuchenstand',        time '08:30', time '18:30', interval '2 hours', 3),
    ('2026-05-23'::date, 'Sonntag',   'Getraenke',          time '08:30', time '18:30', interval '2 hours', 3),
    ('2026-05-23'::date, 'Sonntag',   'Slushi + Sandwich',  time '08:30', time '18:30', interval '2 hour',  3),
    ('2026-05-23'::date, 'Sonntag',   'Human Kicker',       time '16:00', time '18:00', interval '2 hours', 2),
    ('2026-05-23'::date, 'Sonntag',   'Tische abwischen',   time '07:00', time '09:00', interval '2 hours', 2),
    ('2026-05-23'::date, 'Sonntag',   'Tische abwischen',   time '12:30', time '14:30', interval '2 hours', 2),
    ('2026-05-23'::date, 'Sonntag',   'Tische abwischen',   time '19:00', time '21:00', interval '2 hours', 2),

    ('2026-05-24'::date, 'Montag',   'Wannebar',           time '09:00', time '13:00', interval '2 hour',  2),
    ('2026-05-24'::date, 'Montag',   'Kuchenstand',        time '09:00', time '13:00', interval '2 hours', 3),
    ('2026-05-24'::date, 'Montag',   'Getraenke',          time '09:00', time '13:00', interval '2 hours', 3),
    ('2026-05-24'::date, 'Montag',   'Slushi + Sandwich',  time '09:00', time '13:00', interval '2 hour',  3),

    ('2026-05-24'::date, 'Montag',   'Abbau',              time '12:00', time '15:00', interval '3 hour',  15)
  ) as value(slot_day, day_name, location, first_start, last_end, chunk_size, persons_required)
),
chunks as (
  select
    slot_day,
    day_name,
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
insert into public.slots (name, is_taken, day, day_name, location, start, "end")
select
  day_name || ' ' ||
    to_char(start_at, 'HH24:MI') || '-' ||
    to_char(end_at, 'HH24:MI') ||
    ' ' || location ||
    ' Slot ' || person_no as name,
  false as is_taken,
  slot_day,
  day_name,
  location,
  start_at at time zone 'Europe/Berlin',
  end_at at time zone 'Europe/Berlin'
from chunks
where start_at < end_at
order by slot_day, start_at, location, person_no
on conflict (day, location, start, "end", name) do nothing;
