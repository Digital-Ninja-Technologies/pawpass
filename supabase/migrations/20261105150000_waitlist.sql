-- Waitlist for the public landing page (apps/web).
-- Anyone can add an email. Nobody can read the list except staff.

create table public.waitlist_signups (
  id uuid primary key default gen_random_uuid(),
  email text not null check (char_length(email) <= 254 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  source text check (char_length(source) <= 60),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index waitlist_signups_email_key on public.waitlist_signups (lower(email));

create trigger touch_updated_at before update on public.waitlist_signups
  for each row execute function private.touch_updated_at();

alter table public.waitlist_signups enable row level security;

create policy "anyone can join the waitlist" on public.waitlist_signups
  for insert to anon, authenticated
  with check (true);

create policy "staff read the waitlist" on public.waitlist_signups
  for select to authenticated
  using (private.is_staff());

-- Column grants: the public can only set email and source.
revoke all on public.waitlist_signups from anon, authenticated;
grant insert (email, source) on public.waitlist_signups to anon, authenticated;
grant select on public.waitlist_signups to authenticated;
