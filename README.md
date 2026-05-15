# z88

Static signup UI for hockey tournament food/drink shifts backed by Supabase.

## Local preview

```bash
python3 -m http.server 8000
```

Open:

- `http://127.0.0.1:8000/index.html` for parent signup/edit links
- `http://127.0.0.1:8000/admin.html` for the public overview

## Supabase setup

The browser app uses `config.js` and must only contain the publishable key. Do not put a `sb_secret_...` key into static files.

Run `supabase-schema.sql` in the Supabase SQL editor if the `signups` table and policies do not exist yet. The app expects:

- `slots`: `id`, `name`, `is_taken`, `day`, `location`, `start`, `end`
- `signups`: `id`, `name`, `email`, `team`, `slot_id`, `edit_token`, `created_at`, `updated_at`

Use `seed-slots.sql` to generate slots from granular schedule rows. Edit the days, start/end times, chunk sizes, locations, and required person counts in that file before running it.
