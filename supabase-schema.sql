-- Static hosting note:
-- These pages need only a static file host. Keep the service-role / secret key
-- out of all browser files and use only the publishable key in config.js.

-- Your existing table:
-- create table public.signups (
--   id uuid not null default gen_random_uuid (),
--   name text not null,
--   email text null,
--   slot_id uuid null,
--   constraint signups_pkey primary key (id),
--   constraint unique_slot unique (slot_id),
--   constraint signups_slot_id_fkey foreign key (slot_id) references slots (id)
-- );

-- Add the fields needed for Mannschaft and private edit links.
alter table public.signups
  add column if not exists team text not null default '',
  add column if not exists edit_token text,
  add column if not exists created_at timestamp with time zone not null default now(),
  add column if not exists updated_at timestamp with time zone not null default now();

alter table public.slots
  add column if not exists day_name text;

update public.slots
set day_name = case day
  when '2026-05-21'::date then 'Friday'
  when '2026-05-22'::date then 'Saturday'
  when '2026-05-23'::date then 'Sunday'
  when '2026-05-24'::date then 'Monday'
  else day_name
end
where day_name is null;

create index if not exists signups_edit_token_idx on public.signups(edit_token);
create index if not exists signups_slot_id_idx on public.signups(slot_id);

-- Optional but recommended: keep updated_at current when rows are edited.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_signups_updated_at on public.signups;
create trigger set_signups_updated_at
before update on public.signups
for each row
execute function public.set_updated_at();

-- Your after_signup trigger may stay. The static page also updates slots because
-- slot changes after editing are UPDATEs, not INSERTs on signups.
-- create trigger after_signup
-- after insert on signups for each row
-- execute function mark_slot_taken();

-- Keep slots.is_taken consistent with signups.slot_id without changing signups.
create or replace function public.sync_slot_taken_from_signups()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if old.slot_id is not null then
      update public.slots
      set is_taken = exists (
        select 1
        from public.signups
        where slot_id = old.slot_id
      )
      where id = old.slot_id;
    end if;

    return old;
  end if;

  if tg_op in ('INSERT', 'UPDATE') and new.slot_id is not null then
    update public.slots
    set is_taken = true
    where id = new.slot_id;
  end if;

  if tg_op = 'UPDATE' and old.slot_id is not null and old.slot_id is distinct from new.slot_id then
    update public.slots
    set is_taken = exists (
      select 1
      from public.signups
      where slot_id = old.slot_id
    )
    where id = old.slot_id;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_slot_taken_after_signup_change on public.signups;
create trigger sync_slot_taken_after_signup_change
after insert or update of slot_id or delete on public.signups
for each row
execute function public.sync_slot_taken_from_signups();

-- One-time non-destructive repair. This changes only slots.is_taken and never
-- modifies signups, so existing signup links remain valid.
update public.slots
set is_taken = exists (
  select 1
  from public.signups
  where signups.slot_id = slots.id
);

alter table public.slots enable row level security;
alter table public.signups enable row level security;

drop policy if exists "public can read slots" on public.slots;
drop policy if exists "public can update slot taken state" on public.slots;
drop policy if exists "public can read signups" on public.signups;
drop policy if exists "public can insert signups" on public.signups;
drop policy if exists "public can update signups for editing" on public.signups;
drop policy if exists "public can delete signups for editing" on public.signups;

-- The admin overview is public, so SELECT policies intentionally expose overview data.
create policy "public can read slots"
on public.slots for select
to anon
using (true);

create policy "public can update slot taken state"
on public.slots for update
to anon
using (true)
with check (true);

create policy "public can read signups"
on public.signups for select
to anon
using (true);

create policy "public can insert signups"
on public.signups for insert
to anon
with check (true);

create policy "public can update signups for editing"
on public.signups for update
to anon
using (true)
with check (true);

-- No DELETE policy: entries can be edited but not deleted by the static app.
