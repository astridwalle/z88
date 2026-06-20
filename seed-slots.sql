-- Replace public.slots with the tournament schedule for 27-28 June 2026.
-- Edit the schedule values before running this in the Supabase SQL editor.
--
-- Each schedule row creates one row per required person and time chunk.
-- This supports different days, locations, opening hours, chunk sizes, and
-- person counts. Add multiple rows for the same day/location if the chunk size
-- changes during the day.

begin;

-- signups.slot_id references slots.id, so existing assignments must be removed
-- before the old slots can be deleted.
delete from public.signups
where slot_id is not null;

delete from public.slots;

create unique index if not exists slots_unique_seed_idx
on public.slots(day, location, start, "end", name);

with schedule as (
  select *
  from (values
    -- day, day_name, location, first_start, last_end, chunk_size, persons_required
    -- Staffing counts not specified in the source information default to one person.
    -- Each service window includes 30 minutes before and after for setup and cleanup.
    -- During Saturday's ProLeague break, the Wannebar remains open with two people.
    -- The Essensstand is a regular stand with three people, while
    -- Getraenkeausgabe + Tischdienst is staffed only around meal times.
    -- No generated shift is longer than two hours.
    -- Important: the last row before the closing parenthesis must not have a trailing comma.
    ('2026-06-27'::date, 'Samstag', 'Wannebar',                         time '08:30', time '19:00', interval '2 hours', 2),
    ('2026-06-27'::date, 'Samstag', 'Bastelstand',                      time '08:30', time '13:30', interval '2 hours', 1),
    ('2026-06-27'::date, 'Samstag', 'Bastelstand',                      time '15:30', time '19:00', interval '2 hours', 1),
    ('2026-06-27'::date, 'Samstag', 'Tombolastand',                     time '15:30', time '18:30', interval '2 hours', 2),
    ('2026-06-27'::date, 'Samstag', 'Essensstand',                      time '06:30', time '13:30', interval '2 hours', 3),
    ('2026-06-27'::date, 'Samstag', 'Essensstand',                      time '15:30', time '21:00', interval '2 hours', 3),
    ('2026-06-27'::date, 'Samstag', 'Getraenkeausgabe + Tischdienst',  time '06:30', time '09:30', interval '2 hours', 3),
    ('2026-06-27'::date, 'Samstag', 'Getraenkeausgabe + Tischdienst',  time '10:30', time '13:30', interval '2 hours', 3),
    ('2026-06-27'::date, 'Samstag', 'Getraenkeausgabe + Tischdienst',  time '17:30', time '21:00', interval '2 hours', 3),

    ('2026-06-28'::date, 'Sonntag', 'Wannebar',                         time '07:30', time '12:00', interval '2 hours', 2),
    ('2026-06-28'::date, 'Sonntag', 'Bastelstand',                      time '07:30', time '12:00', interval '2 hours', 1),
    ('2026-06-28'::date, 'Sonntag', 'Essensstand',                      time '06:30', time '13:30', interval '2 hours', 3),
    ('2026-06-28'::date, 'Sonntag', 'Getraenkeausgabe + Tischdienst',  time '06:30', time '09:30', interval '2 hours', 3),
    ('2026-06-28'::date, 'Sonntag', 'Getraenkeausgabe + Tischdienst',  time '10:30', time '13:30', interval '2 hours', 3)
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

commit;
