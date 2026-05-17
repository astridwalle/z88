-- Non-destructive repair for stale slots.is_taken values.
-- This updates only public.slots.is_taken based on existing public.signups rows.
-- It does not insert, update, or delete any signups.

update public.slots
set is_taken = exists (
  select 1
  from public.signups
  where signups.slot_id = slots.id
);

-- Optional check: slots marked taken but without a signup should return 0 rows.
select slots.id, slots.name, slots.is_taken
from public.slots
left join public.signups on signups.slot_id = slots.id
where slots.is_taken is true
  and signups.id is null
order by slots.day, slots.start, slots.location, slots.name;
